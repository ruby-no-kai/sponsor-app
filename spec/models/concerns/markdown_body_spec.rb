require 'rails_helper'

RSpec.describe MarkdownBody do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include ActiveModel::Model
      include MarkdownBody

      attr_accessor :id, :body, :updated_at

      def persisted?
        !!id
      end

      def self.name
        'MarkdownBodyTest'
      end
    end
  end

  let(:instance) { test_class.new(body: markdown_text) }
  let(:markdown_text) { "# Hello\n\nThis is **bold** text." }

  describe '#render_html' do
    it 'converts markdown to HTML' do
      html = instance.render_html
      expect(html).to include('<h1')
      expect(html).to include('Hello')
      expect(html).to include('<strong>bold</strong>')
    end

    it 'enables strikethrough extension' do
      instance.body = '~~strikethrough~~'
      html = instance.render_html
      expect(html).to include('<del>strikethrough</del>')
    end

    it 'enables table extension' do
      instance.body = "| Col1 | Col2 |\n|------|------|\n| A    | B    |"
      html = instance.render_html
      expect(html).to include('<table')
      expect(html).to include('<th')
    end

    it 'enables autolink extension' do
      instance.body = 'Visit https://example.com'
      html = instance.render_html
      expect(html).to include('<a href="https://example.com"')
    end

    it 'allows unsafe HTML when unsafe: true' do
      instance.body = '<script>alert("test")</script>'
      html = instance.render_html
      expect(html).to include('<script>')
    end

    it 'generates header IDs with record ID prefix' do
      instance.id = 123
      instance.body = '# Test Header'
      html = instance.render_html
      expect(html).to include('id="123--test-header"')
    end

    it 'handles nil ID for header_ids' do
      instance.id = nil
      instance.body = '# Test Header'
      expect { instance.render_html }.not_to raise_error
    end
  end

  describe '#html' do
    context 'when record is not persisted' do
      before { allow(instance).to receive(:persisted?).and_return(false) }

      it 'renders HTML without caching' do
        html = instance.html
        expect(html).to include('Hello')
        expect(html).to be_html_safe
      end

      it 'does not use Rails cache' do
        expect(Rails.cache).not_to receive(:fetch)
        instance.html
      end
    end

    context 'when record is persisted' do
      before do
        instance.id = 123
        instance.updated_at = Time.current
        allow(instance).to receive(:persisted?).and_return(true)
      end

      it 'renders HTML with caching' do
        html = instance.html
        expect(html).to include('Hello')
        expect(html).to be_html_safe
      end

      it 'uses Rails cache with appropriate key' do
        cache_key = "MarkdownBodyTest:html:#{instance.id}/#{instance.updated_at.to_f}"
        expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 1.month).and_call_original
        instance.html
      end

      it 'returns cached result on subsequent calls' do
        # First call to populate cache
        first_result = instance.html

        # Mock cache to return the cached value without calling the block
        cache_key = "MarkdownBodyTest:html:#{instance.id}/#{instance.updated_at.to_f}"
        allow(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 1.month).and_return(first_result)

        # Stub render_html to ensure it's not called again
        expect(instance).not_to receive(:render_html)

        # Second call should use cache
        second_result = instance.html
        expect(second_result).to eq(first_result)
      end

      it 'busts cache when updated_at changes' do
        first_result = instance.html

        # Change updated_at
        instance.updated_at = 1.hour.from_now
        instance.body = '# Changed'

        # Should call render_html again
        second_result = instance.html
        expect(second_result).not_to eq(first_result)
        expect(second_result).to include('Changed')
      end
    end
  end
end
