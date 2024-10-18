import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';

export interface ChatMessage {
  message: string;
  conversation_id: string;
}

export interface ChatResponse {
  message: string;
  metadata: {
    conversation_id: string;
    duration: number;
    tokens_evaluated: number;
  };
}

export interface SearchResult {
  title: string;
  link: string;
  snippet: string;
}

export interface ImageSearchResult {
  title: string;
  link: string;
  thumbnailLink: string;
  displayLink: string;
  mime: string;
  fileFormat?: string;
  contextLink?: string;
}

export interface SearchResponse {
  results?: SearchResult[];
  images?: ImageSearchResult[];
}

export interface DocumentAnalysisResult {
  filename: string;
  content: string;
  metadata: {
    [key: string]: any;
  };
}

@Injectable({
  providedIn: 'root'
})
export class ChatService {
  private apiUrl = 'http://192.168.1.90:8000/api';

  constructor(private http: HttpClient) {}

  sendMessage(chatMessage: ChatMessage): Observable<ChatResponse> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json'
    });

    chatMessage.conversation_id = chatMessage.conversation_id || '';

    console.log('Sending message:', chatMessage);

    return this.http.post<ChatResponse>(`${this.apiUrl}/chat`, chatMessage, { headers }).pipe(
      tap(response => console.log('Received response:', response)),
      catchError(this.handleError)
    );
  }

  performSearch(query: string, type: 'web' | 'image' = 'web'): Observable<SearchResponse> {
    return this.http.get<SearchResponse>(`${this.apiUrl}/search`, { params: { q: query, type } });
  }

  analyzeDocument(file: File): Observable<DocumentAnalysisResult> {
    const formData = new FormData();
    formData.append('file', file);

    return this.http.post<DocumentAnalysisResult>(`${this.apiUrl}/analyze-document`, formData).pipe(
      catchError(this.handleError)
    );
  }

  private handleError(error: HttpErrorResponse) {
    console.error('Full error object:', error);

    let errorMessage = 'An unknown error occurred';
    if (error.error instanceof ErrorEvent) {
      errorMessage = `Error: ${error.error.message}`;
    } else {
      errorMessage = `Backend returned code ${error.status}, body was: ${JSON.stringify(error.error)}`;
    }

    console.error(errorMessage);
    return throwError(() => new Error(errorMessage));
  }
}
