import { Component, OnInit, ViewChild, ElementRef, AfterViewInit } from '@angular/core';
import { FormsModule } from "@angular/forms";
import { CommonModule, NgClass, NgFor, NgIf } from "@angular/common";
import { ChatService, ChatMessage, ChatResponse, DocumentAnalysisResult } from "../chat.service";
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { MarkdownToHtmlPipe } from "../markdown-to-html-pipe.pipe";

interface DisplayMessage {
  role: 'user' | 'assistant';
  content: string;
}

@Component({
  selector: 'app-chat',
  templateUrl: './chat.component.html',
  styleUrls: ['./chat.component.sass'],
  standalone: true,
  imports: [FormsModule, NgClass, NgFor, NgIf, CommonModule, MarkdownToHtmlPipe],
  providers: [ChatService]
})
export class ChatComponent implements OnInit {
  @ViewChild('chatInput') chatInputElement!: ElementRef<HTMLTextAreaElement>;

  messages: any[] = [];
  userInput = '';
  isLoading = false;
  conversationId: string = '';

  constructor(private chatService: ChatService) {}

  ngOnInit() {
    this.messages.push({
      role: 'assistant',
      content: 'Hello! How can I assist you today? You can ask me questions, request a web search, or upload a document for analysis.'
    });
  }

  sendMessage() {
    if (this.userInput.trim() === '' || this.isLoading) return;

    this.isLoading = true;
    const userMessage = this.userInput;
    this.messages.push({ role: 'user', content: userMessage });
    this.userInput = '';

    if (userMessage.toLowerCase().startsWith('search for ')) {
      this.performWebSearch(userMessage.slice(11));
    } else if (userMessage.toLowerCase().startsWith('image search ')) {
      this.performImageSearch(userMessage.slice(13));
    } else {
      this.sendChatMessage(userMessage);
    }
  }

  private sendChatMessage(message: string) {
    const chatMessage: ChatMessage = {
      message: message,
      conversation_id: this.conversationId
    };

    this.chatService.sendMessage(chatMessage).subscribe({
      next: (response: ChatResponse) => {
        this.messages.push({
          role: 'assistant',
          content: response.message
        });
        if (response.metadata && response.metadata.conversation_id) {
          this.conversationId = response.metadata.conversation_id;
        }
      },
      error: (error) => {
        console.error('Error sending message:', error);
        this.messages.push({
          role: 'assistant',
          content: 'An error occurred. Please try again.'
        });
      },
      complete: () => {
        this.isLoading = false;
      }
    });
  }

  onFileSelected(event: any) {
    const file: File = event.target.files[0];
    if (file) {
      this.isLoading = true;
      this.chatService.analyzeDocument(file).subscribe({
        next: (result: DocumentAnalysisResult) => {
          this.messages.push({
            role: 'assistant',
            content: `Document analysis complete for ${result.filename}`,
            documentAnalysis: result
          });
        },
        error: (error) => {
          console.error('Document analysis error:', error);
          this.messages.push({
            role: 'assistant',
            content: 'Sorry, an error occurred while analyzing the document. Please try again.'
          });
        },
        complete: () => {
          this.isLoading = false;
        }
      });
    }
  }

  private performWebSearch(query: string) {
    this.chatService.performSearch(query, 'web').subscribe({
      next: (response) => {
        if (response.results) {
          this.messages.push({
            role: 'web-search',
            content: `Web search results for "${query}":`,
            searchResults: response.results
          });
        } else {
          this.messages.push({
            role: 'assistant',
            content: 'No web search results found.'
          });
        }
      },
      error: (error) => {
        console.error('Web search error:', error);
        this.messages.push({
          role: 'assistant',
          content: 'Sorry, an error occurred while performing the web search. Please try again.'
        });
      },
      complete: () => {
        this.isLoading = false;
      }
    });
  }

  private performImageSearch(query: string) {
    this.chatService.performSearch(query, 'image').subscribe({
      next: (response) => {
        if (response.images) {
          this.messages.push({
            role: 'image-search',
            content: `Image search results for "${query}":`,
            imageResults: response.images
          });
        } else {
          this.messages.push({
            role: 'assistant',
            content: 'No image search results found.'
          });
        }
      },
      error: (error) => {
        console.error('Image search error:', error);
        this.messages.push({
          role: 'assistant',
          content: 'Sorry, an error occurred while performing the image search. Please try again.'
        });
      },
      complete: () => {
        this.isLoading = false;
      }
    });
  }
}
