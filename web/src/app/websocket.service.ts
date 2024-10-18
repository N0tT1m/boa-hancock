import { Injectable } from '@angular/core';
import { Observable, Subject } from 'rxjs';

export interface ChatMessage {
  message: string;
  metadata?: {
    duration: number;
    tokens_evaluated: number;
  };
}

@Injectable({
  providedIn: 'root'
})
export class WebSocketService {
  private socket: WebSocket;
  private messagesSubject = new Subject<ChatMessage>();

  constructor() {
    this.socket = new WebSocket('ws://localhost:8765');
    this.socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.messagesSubject.next(data);
    };
  }

  public connect(): Observable<ChatMessage> {
    return this.messagesSubject.asObservable();
  }

  public sendMessage(message: string): void {
    this.socket.send(JSON.stringify({ message }));
  }

  public close(): void {
    this.socket.close();
  }
}
