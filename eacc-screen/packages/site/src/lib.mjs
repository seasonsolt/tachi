const LIST_FIELDS = new Set([
  'monetizationMode',
  'related',
  'keywords',
  'featuredHubSlugs',
  'featuredWorkflowSlugs',
  'featuredComparisonSlugs',
  'relatedHubSlugs',
  'relatedComparisonSlugs',
  'relatedWorkflowSlugs',
]);

export function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function escapeAttribute(value) {
  return escapeHtml(value).replace(/`/g, '&#96;');
}

export function splitList(value = '') {
  return String(value)
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export function parseFrontmatter(raw) {
  const normalized = String(raw).replace(/\r\n/g, '\n').trim();
  if (!normalized.startsWith('---\n')) {
    return { meta: {}, body: normalized };
  }

  const delimiter = '\n---\n';
  const end = normalized.indexOf(delimiter, 4);
  if (end === -1) {
    return { meta: {}, body: normalized };
  }

  const head = normalized.slice(4, end).split('\n');
  const body = normalized.slice(end + delimiter.length).trim();
  const meta = {};

  for (let index = 0; index < head.length; index += 1) {
    const line = head[index];
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const separator = trimmed.indexOf(':');
    if (separator === -1) continue;
    const key = trimmed.slice(0, separator).trim();
    const rawValue = trimmed.slice(separator + 1).trim();
    if (!key) continue;

    if (!rawValue) {
      const items = [];
      while (index + 1 < head.length) {
        const nextLine = head[index + 1].trim();
        if (!nextLine.startsWith('- ')) break;
        items.push(nextLine.slice(2).trim());
        index += 1;
      }
      meta[key] = items;
    } else if (LIST_FIELDS.has(key)) {
      meta[key] = splitList(rawValue);
    } else if (rawValue === 'true' || rawValue === 'false') {
      meta[key] = rawValue === 'true';
    } else {
      meta[key] = rawValue;
    }
  }

  return { meta, body };
}

function renderInline(markdown) {
  let html = escapeHtml(markdown);
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
  html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, url) => {
    return `<a href="${escapeAttribute(url)}">${label}</a>`;
  });
  return html;
}

export function markdownToHtml(markdown) {
  const lines = String(markdown).replace(/\r\n/g, '\n').split('\n');
  const html = [];
  let paragraph = [];
  let listItems = [];
  let listType = null;
  let quoteLines = [];
  let codeFence = null;
  let codeLines = [];

  const flushParagraph = () => {
    if (!paragraph.length) return;
    html.push(`<p>${renderInline(paragraph.join(' '))}</p>`);
    paragraph = [];
  };

  const flushList = () => {
    if (!listItems.length || !listType) return;
    const items = listItems.map((item) => `<li>${renderInline(item)}</li>`).join('');
    html.push(`<${listType}>${items}</${listType}>`);
    listItems = [];
    listType = null;
  };

  const flushQuote = () => {
    if (!quoteLines.length) return;
    html.push(`<blockquote><p>${renderInline(quoteLines.join(' '))}</p></blockquote>`);
    quoteLines = [];
  };

  const flushCode = () => {
    if (!codeFence) return;
    const className = codeFence ? ` class="language-${escapeAttribute(codeFence)}"` : '';
    html.push(`<pre><code${className}>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
    codeFence = null;
    codeLines = [];
  };

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();

    if (line.startsWith('```')) {
      if (codeFence !== null) {
        flushCode();
      } else {
        flushParagraph();
        flushList();
        flushQuote();
        codeFence = line.slice(3).trim();
      }
      continue;
    }

    if (codeFence !== null) {
      codeLines.push(rawLine);
      continue;
    }

    if (!line.trim()) {
      flushParagraph();
      flushList();
      flushQuote();
      continue;
    }

    const headingMatch = line.match(/^(#{1,3})\s+(.*)$/);
    if (headingMatch) {
      flushParagraph();
      flushList();
      flushQuote();
      const level = Math.min(headingMatch[1].length + 1, 4);
      html.push(`<h${level}>${renderInline(headingMatch[2])}</h${level}>`);
      continue;
    }

    if (line === '---') {
      flushParagraph();
      flushList();
      flushQuote();
      html.push('<hr />');
      continue;
    }

    const quoteMatch = line.match(/^>\s?(.*)$/);
    if (quoteMatch) {
      flushParagraph();
      flushList();
      quoteLines.push(quoteMatch[1]);
      continue;
    }

    const unorderedMatch = line.match(/^-\s+(.*)$/);
    if (unorderedMatch) {
      flushParagraph();
      flushQuote();
      if (listType && listType !== 'ul') flushList();
      listType = 'ul';
      listItems.push(unorderedMatch[1]);
      continue;
    }

    const orderedMatch = line.match(/^\d+\.\s+(.*)$/);
    if (orderedMatch) {
      flushParagraph();
      flushQuote();
      if (listType && listType !== 'ol') flushList();
      listType = 'ol';
      listItems.push(orderedMatch[1]);
      continue;
    }

    flushList();
    flushQuote();
    paragraph.push(line.trim());
  }

  flushParagraph();
  flushList();
  flushQuote();
  flushCode();

  return html.join('\n');
}

export function isExternalUrl(value) {
  return /^https?:\/\//.test(String(value));
}

export function normalizePath(value) {
  if (!value || value === '/') return '/';
  const trimmed = String(value).trim();
  const withLeadingSlash = trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  return withLeadingSlash.length > 1 && withLeadingSlash.endsWith('/')
    ? withLeadingSlash.slice(0, -1)
    : withLeadingSlash;
}

export function formatDateLabel(value) {
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isNaN(date.getTime())
    ? value
    : new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' }).format(date);
}
