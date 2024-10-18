import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../environments/environments';

export interface ChatMessage {
  message: string;
  conversation_id?: string | null;
}

export interface ChatResponse {
  message: string;
  metadata: {
    conversation_id: string;
    duration: number;
    tokens_evaluated: number;
  };
}

@Injectable({
  providedIn: 'root'
})
export class ChatService {
  http: HttpClient = inject(HttpClient)

  private apiUrl = `${environment.apiUrl}/api/chat`;

  sendMessage(chatMessage: ChatMessage): Observable<ChatResponse> {
    return this.http.post<ChatResponse>(this.apiUrl, chatMessage);
  }
}
