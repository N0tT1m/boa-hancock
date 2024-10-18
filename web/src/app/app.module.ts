import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { FormsModule } from '@angular/forms';
import { AppComponent } from './app.component';
import { ChatComponent } from './chat/chat.component';
import { StartWindowComponent } from './start-window/start-window.component';
import { WebSocketService } from './websocket.service';

@NgModule({
  declarations: [],
  imports: [BrowserModule, FormsModule],
  providers: [WebSocketService],
  bootstrap: []
})
export class AppModule { }
