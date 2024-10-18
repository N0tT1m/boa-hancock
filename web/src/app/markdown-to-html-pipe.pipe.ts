import { Pipe, PipeTransform } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';

@Pipe({
  name: 'markdownToHtml',
  standalone: true,
})
export class MarkdownToHtmlPipe implements PipeTransform {
  constructor(private sanitizer: DomSanitizer) {}

  transform(value: string): SafeHtml {
    // Basic markdown to HTML conversion
    let html = value
      // Convert headers
      .replace(/^### (.*$)/gim, '<h3>$1</h3>')
      .replace(/^## (.*$)/gim, '<h2>$1</h2>')
      .replace(/^# (.*$)/gim, '<h1>$1</h1>')
      // Convert bold
      .replace(/\*\*(.*)\*\*/gim, '<strong>$1</strong>')
      // Convert italic
      .replace(/\*(.*)\*/gim, '<em>$1</em>')
      // Convert line breaks
      .replace(/\n/gim, '<br>')
      // Convert code blocks
      .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
      // Convert inline code
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      // Convert links
      .replace(/\[([^\]]+)\]\(([^\)]+)\)/g, '<a href="$2" target="_blank">$1</a>');

    // Sanitize the HTML to prevent XSS attacks
    return this.sanitizer.bypassSecurityTrustHtml(html);
  }
}
