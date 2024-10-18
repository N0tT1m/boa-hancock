import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { FormsModule } from '@angular/forms';
import { AppComponent } from './app.component';
import { MarkdownToHtmlPipe } from './markdown-to-html-pipe.pipe';

@NgModule({
  declarations: [
    MarkdownToHtmlPipe
  ],
  imports: [
    BrowserModule,
    FormsModule
  ],
  providers: [],
  bootstrap: []
})
export class BoaHancockModule { }
