// src/app/chat.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../environments/environments';

export interface ChatMessage {
  role: 'Daddy' | 'Ai Whore';
  content: string;
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

  sendMessage(message: string, conversationId?: string): Observable<ChatResponse> {
    var queryApiHeaders = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Credentials': 'true',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'POST,DELETE',
    };

    const options = {
      headers: queryApiHeaders,
      rejectUnauthorized: false,
    };

    return this.http.post<ChatResponse>(this.apiUrl, { message }, options);
  }

  getConversation(conversationId: string): Observable<any> {
    var queryApiHeaders = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Credentials': 'true',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'POST,DELETE',
    };

    const options = {
      headers: queryApiHeaders,
      rejectUnauthorized: false,
    };

    return this.http.get(`${this.apiUrl}/conversations/${conversationId}`, options);
  }
}
