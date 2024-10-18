import { Component, OnInit, ViewChild, ElementRef, AfterViewInit } from '@angular/core';
import { FormsModule } from "@angular/forms";
import { CommonModule, NgClass, NgFor, NgIf } from "@angular/common";
import { ChatService, ChatMessage, ChatResponse } from "../chat.service";
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
export class ChatComponent implements OnInit, AfterViewInit {
  @ViewChild('chatInput') chatInputElement!: ElementRef<HTMLTextAreaElement>;

  messages: DisplayMessage[] = [];
  userInput = '';
  isLoading = false;
  conversationId: string | null = null;

  constructor(
    private chatService: ChatService,
    private sanitizer: DomSanitizer
  ) {
    console.log('ChatComponent constructed');
  }

  ngOnInit() {
    console.log('ChatComponent initialized');
    this.messages.push({
      role: 'assistant',
      content: 'Hello! How can I assist you today?'
    });
  }

  ngAfterViewInit() {
    this.resizeTextarea();
  }

  onKeyDown(event: KeyboardEvent) {
    const textarea = event.target as HTMLTextAreaElement;
    if (event.key === 'Enter') {
      if (event.shiftKey) {
        this.resizeTextarea();
      } else {
        event.preventDefault();
        this.sendMessage();
      }
    } else {
      setTimeout(() => this.resizeTextarea(), 0);
    }
  }

  resizeTextarea() {
    const textarea = this.chatInputElement?.nativeElement;
    if (textarea) {
      textarea.style.height = 'auto';
      textarea.style.height = textarea.scrollHeight + 'px';
      textarea.classList.toggle('multiline', textarea.value.includes('\n'));
    }
  }

  sendMessage() {
    if (this.userInput.trim() === '' || this.isLoading) return;

    const userMessage: DisplayMessage = { role: 'user', content: this.userInput };
    this.messages.push(userMessage);
    this.isLoading = true;

    const userInputCopy = this.userInput;
    this.userInput = ''; // Clear input immediately
    this.resizeTextarea();

    const chatMessage: ChatMessage = {
      message: userInputCopy,
    };

    if (this.conversationId) {
      chatMessage.conversation_id = this.conversationId;
    }

    this.chatService.sendMessage(chatMessage).subscribe({
      next: (response) => {
        this.handleResponse(response);
      },
      error: (error) => {
        console.error('Error:', error);
        this.messages.push({
          role: 'assistant',
          content: 'Sorry, an error occurred. Please try again.'
        });
        this.isLoading = false;
      },
      complete: () => {
        this.isLoading = false;
      }
    });
  }

  private handleResponse(response: ChatResponse) {
    const assistantMessage: DisplayMessage = { role: 'assistant', content: response.message };
    this.messages.push(assistantMessage);

    // Always update the conversation ID
    this.conversationId = response.metadata.conversation_id;

    console.log(`Response generated in ${response.metadata.duration.toFixed(2)} seconds`);
    console.log(`Tokens evaluated: ${response.metadata.tokens_evaluated}`);
  }

  formatMessage(content: string): SafeHtml {
    // Replace code blocks
    const formattedContent = content.replace(/```([\s\S]*?)```/g, (match, code) => {
      return `<pre><code>${this.escapeHtml(code.trim())}</code></pre>`;
    });
    // Sanitize the HTML to prevent XSS attacks
    return this.sanitizer.bypassSecurityTrustHtml(formattedContent);
  }

  private escapeHtml(unsafe: string): string {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }
}
