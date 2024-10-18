// src/app/app.component.ts
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { StartWindowComponent } from './start-window/start-window.component';
import { ChatComponent } from './chat/chat.component';
import { HttpClientModule } from '@angular/common/http';

@Component({
  selector: 'app-root',
  template: `
    <app-start-window *ngIf="!chatStarted" (startChat)="onStartChat()"></app-start-window>
    <app-chat *ngIf="chatStarted"></app-chat>
  `,
  standalone: true,
  imports: [CommonModule, StartWindowComponent, ChatComponent, HttpClientModule],
})
export class AppComponent {
  chatStarted = false;

  onStartChat() {
    console.log('onStartChat called in AppComponent');
    this.chatStarted = true;
    console.log('chatStarted set to:', this.chatStarted);
  }
}
