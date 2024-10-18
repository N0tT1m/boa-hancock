import { Component, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-start-window',
  templateUrl: './start-window.component.html',
  styleUrls: ['./start-window.component.sass'],
  standalone: true,
})
export class StartWindowComponent {
  @Output() startChat = new EventEmitter<void>();

  onStartChat() {
    this.startChat.emit();
  }
}
