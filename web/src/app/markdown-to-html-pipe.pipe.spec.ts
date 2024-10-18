import { MarkdownToHtmlPipePipe } from './markdown-to-html-pipe.pipe';

describe('MarkdownToHtmlPipePipe', () => {
  it('create an instance', () => {
    const pipe = new MarkdownToHtmlPipePipe();
    expect(pipe).toBeTruthy();
  });
});
