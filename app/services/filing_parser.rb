require "nokogiri"

class FilingParser
  # Standard 10-K item structure
  ITEMS_10K = {
    "1" => "Business",
    "1A" => "Risk Factors",
    "1B" => "Unresolved Staff Comments",
    "1C" => "Cybersecurity",
    "2" => "Properties",
    "3" => "Legal Proceedings",
    "4" => "Mine Safety Disclosures",
    "5" => "Market for Registrant's Common Equity",
    "6" => "Reserved",
    "7" => "Management's Discussion and Analysis",
    "7A" => "Quantitative and Qualitative Disclosures About Market Risk",
    "8" => "Financial Statements and Supplementary Data",
    "9" => "Changes in and Disagreements with Accountants",
    "9A" => "Controls and Procedures",
    "9B" => "Other Information",
    "10" => "Directors, Executive Officers and Corporate Governance",
    "11" => "Executive Compensation",
    "12" => "Security Ownership",
    "13" => "Certain Relationships and Related Transactions",
    "14" => "Principal Accountant Fees and Services",
    "15" => "Exhibits and Financial Statement Schedules",
    "16" => "Form 10-K Summary"
  }.freeze

  # Standard 10-Q item structure
  ITEMS_10Q = {
    "1" => "Financial Statements",
    "2" => "Management's Discussion and Analysis",
    "3" => "Quantitative and Qualitative Disclosures About Market Risk",
    "4" => "Controls and Procedures",
    "1_P2" => "Legal Proceedings",
    "1A_P2" => "Risk Factors",
    "2_P2" => "Unregistered Sales of Equity Securities",
    "3_P2" => "Defaults Upon Senior Securities",
    "4_P2" => "Mine Safety Disclosures",
    "5_P2" => "Other Information",
    "6_P2" => "Exhibits"
  }.freeze

  # Sections collapsed by default in the reader
  COLLAPSIBLE_PATTERNS = [
    /forward.looking\s+statements/i,
    /cautionary\s+(note|statement)/i,
    /signatures?$/i,
    /exhibits?\s+(and\s+)?financial\s+statement/i,
    /mine\s+safety/i,
    /form\s+10-[kq]\s+summary/i,
    /reserved$/i
  ].freeze

  # Parse raw SEC filing HTML into structured sections.
  # Returns a hash: { "sections" => [ { title:, anchor:, content_html:, collapsible: }, ... ] }
  def self.parse(html, form_type)
    doc = Nokogiri::HTML(html)

    # Strip XBRL/iXBRL tags but preserve their inner content
    strip_xbrl_tags(doc)

    # Find section boundaries
    items = form_type == "10-K" ? ITEMS_10K : ITEMS_10Q
    sections = extract_sections(doc, items)

    # If we couldn't find structured sections, fall back to the whole body
    if sections.empty?
      sections = [ {
        "title" => "Filing Content",
        "anchor" => "content",
        "content_html" => clean_html(doc.at_css("body")&.inner_html || ""),
        "collapsible" => false
      } ]
    end

    { "sections" => sections }
  end

  private

  # Remove XBRL namespace tags while keeping their text content
  def self.strip_xbrl_tags(doc)
    # Remove ix: namespaced elements (iXBRL inline tags), keeping children
    doc.css("[class*='xbrl']").each { |node| node.replace(node.children) }

    # Handle ix: namespace tags (e.g., ix:nonNumeric, ix:nonFraction)
    doc.xpath("//*[starts-with(name(), 'ix:')]").each { |node| node.replace(node.children) }

    # Remove hidden XBRL elements
    doc.css("[style*='display:none'], [style*='display: none']").each(&:remove)

    # Remove the xbrl wrapper if present
    doc.css("xbrl").each { |node| node.replace(node.children) }
  end

  # Find Item headers in the document and extract content between them
  def self.extract_sections(doc, items)
    body = doc.at_css("body")
    return [] unless body

    # Build a regex that matches "Item 1", "Item 1A", "ITEM 7A" etc.
    item_pattern = /\A\s*(?:PART\s+[IV]+\s*[-—.]?\s*)?ITEM\s+(\d+[A-Z]?)[\s.—:-]+(.+)/i

    # Walk through all text-bearing elements looking for item headers
    headers = []
    body.traverse do |node|
      next unless node.text?
      next unless node.text.strip.match?(item_pattern)

      # Check if this text node is inside a bold/strong/heading element
      parent = node.parent
      is_header = parent&.name&.match?(/\A(b|strong|h[1-6])\z/) ||
                  parent&.[]("class")&.match?(/bold|header|heading/i) ||
                  (parent&.[]("style")&.match?(/font-weight\s*:\s*(bold|[7-9]00)/i))

      # Also consider if text is all-caps (common in SEC filings)
      text = node.text.strip
      is_header ||= text == text.upcase && text.length > 5

      if is_header || text.match?(/\A\s*ITEM\s+\d/i)
        match = text.match(item_pattern)
        if match
          item_num = match[1].upcase
          headers << { item: item_num, node: find_block_ancestor(node), text: text }
        end
      end
    end

    # Deduplicate headers (table of contents entries vs actual content)
    # Keep the last occurrence of each item (usually the actual section, not the TOC reference)
    seen = {}
    headers.each_with_index do |h, i|
      seen[h[:item]] = i
    end
    headers = seen.map { |_item, i| headers[i] }

    # Extract content between headers
    sections = []
    headers.each_with_index do |header, i|
      start_node = header[:node]
      end_node = headers[i + 1]&.dig(:node)

      title = items[header[:item]] || header[:text].sub(/\A.*?ITEM\s+\d+[A-Z]?\s*[-—:.]\s*/i, "").strip
      title = "Item #{header[:item]} — #{title}"

      content = extract_content_between(start_node, end_node)
      content_html = clean_html(content)

      next if content_html.strip.empty?

      sections << {
        "title" => title,
        "anchor" => "item-#{header[:item].downcase}",
        "content_html" => content_html,
        "collapsible" => collapsible?(title)
      }
    end

    sections
  end

  # Walk up from a text node to find its block-level ancestor
  def self.find_block_ancestor(node)
    current = node.parent
    while current && current.name.match?(/\A(b|strong|em|i|span|font|a)\z/i)
      current = current.parent
    end
    current || node.parent
  end

  # Extract HTML content between two sibling-ish nodes
  def self.extract_content_between(start_node, end_node)
    content = []
    current = start_node

    while current
      break if end_node && current == end_node

      content << current.to_html
      current = current.next_sibling || next_element_after(current)

      # Safety: don't collect more than 5MB
      break if content.sum(&:length) > 5_000_000
    end

    content.join
  end

  # When there's no next sibling, walk up to find the next element
  def self.next_element_after(node)
    current = node
    while current.parent && current.parent.name != "body"
      sibling = current.parent.next_sibling
      return sibling if sibling
      current = current.parent
    end
    nil
  end

  # Clean HTML: convert SEC filing structure into readable semantic HTML
  def self.clean_html(html)
    return "" if html.nil? || html.strip.empty?

    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    # ── Phase 1: Remove junk before any transformations ──

    # Convert styled spans to semantic tags BEFORE stripping styles
    # font-weight:700/bold → <strong>, font-style:italic → <em>
    # Skip spans inside tables — those keep their original styles
    doc.css("span[style]").each do |span|
      next if span.ancestors("table").any?

      style = span["style"].to_s
      is_bold = style.match?(/font-weight\s*:\s*(bold|[7-9]00)/i)
      is_italic = style.match?(/font-style\s*:\s*italic/i)

      if is_bold && span.text.strip.present?
        strong = doc.document.create_element("strong")
        strong.inner_html = span.inner_html
        span.replace(strong)
      elsif is_italic && span.text.strip.present?
        em = doc.document.create_element("em")
        em.inner_html = span.inner_html
        span.replace(em)
      end
    end

    # Also convert <b> tags to <strong> for consistency (outside tables)
    doc.css("b").each { |node| node.name = "strong" unless node.ancestors("table").any? }
    doc.css("i").each { |node| node.name = "em" unless node.ancestors("table").any? }

    # Remove inline styles — but preserve ALL styles inside tables
    doc.css("[style]").each do |node|
      next if node.name == "table" || node.ancestors("table").any?
      node.remove_attribute("style")
    end

    # Remove font tags, keeping children
    doc.css("font").each { |node| node.replace(node.children) }

    # Remove class and id attributes
    doc.css("[class]").each { |node| node.remove_attribute("class") }
    doc.css("[id]").each { |node| node.remove_attribute("id") }

    # Remove ALL "Table of Contents" elements — handles text split across
    # multiple <a>/<span> tags (e.g., <a>Table </a><a>of Cont</a><a>ents</a>)
    doc.css("div, p, h1, h2, h3, h4, h5, h6").each do |node|
      next if node.at_css("table, div, p")
      text = node.text.gsub(/\s+/, " ").strip
      node.remove if text.match?(/\ATable of Contents\z/i)
    end

    # Remove excessive <hr> tags (SEC page break artifacts)
    doc.css("hr").each(&:remove)

    # Remove <br> only elements and empty spacer divs
    doc.css("div, span, p").each do |node|
      next if node.at_css("table, img")
      inner = node.inner_html.strip
      # Remove if empty or only contains <br> tags / whitespace
      node.remove if inner.empty? || inner.gsub(/<br\s*\/?>/, "").strip.empty?
    end

    # Remove standalone page numbers (bare numbers like "63", "64")
    doc.css("div").each do |div|
      next if div.at_css("table, div")
      text = div.text.strip
      div.remove if text.match?(/\A\d{1,3}\z/)
    end

    # Remove redundant "ITEM X." headers (the section title already has this)
    doc.css("div").each do |div|
      next if div.at_css("table, div")
      text = div.text.strip
      div.remove if text.match?(/\A(PART\s+[IV]+\s*[-—.]?\s*)?ITEM\s+\d+[A-Z]?\s*[.—:]/i)
    end

    # ── Phase 2: Convert structure to semantic HTML ──

    # Convert div>span paragraphs into <p> or <h3> tags
    doc.css("div").each do |div|
      # Skip structural containers and table contents
      next if div.at_css("table, div")
      next if div.ancestors("table").any?

      text = div.text.strip
      next if text.empty?

      # Detect subheadings: short text (< 80 chars), no period at end,
      # not a bare number, has at least 2 word characters
      is_subheading = text.length < 80 &&
                      !text.end_with?(".") &&
                      !text.match?(/\A[\d,.\s$%()\-]+\z/) &&
                      text.match?(/[a-zA-Z]{2,}/) &&
                      div.css("span").length <= 2

      tag = is_subheading ? "h3" : "p"
      new_node = doc.document.create_element(tag)
      new_node["data-subheading"] = "true" if is_subheading
      new_node.inner_html = div.inner_html
      div.replace(new_node)
    end

    # ── Phase 3: Clean up ──

    # Unwrap unnecessary spans inside paragraphs (clean up span soup)
    doc.css("p, h3[data-subheading]").each do |node|
      node.css("span").each { |span| span.replace(span.children) }
    end

    # Remove "Table of Contents" elements that survived (text may be split across child nodes)
    doc.css("p, h3, div").each do |node|
      next if node.at_css("table, div, p")
      text = node.text.gsub(/\s+/, " ").strip
      node.remove if text.match?(/\ATable of Contents\z/i)
    end

    # Remove empty paragraphs and subheadings
    doc.css("p, h3[data-subheading]").each do |node|
      node.remove if node.text.strip.empty? && node.css("img, table").empty?
    end

    # Remove remaining empty divs
    doc.css("div").each do |div|
      div.remove if div.text.strip.empty? && div.css("table, img").empty?
    end

    # ── Phase 4: Group bullet points into <ul><li> lists ──
    group_bullet_points(doc)

    # ── Phase 5: Wrap tables in scroll containers ──
    doc.css("table").each do |table|
      wrapper = doc.document.create_element("div")
      wrapper["class"] = "table-wrapper"
      table.replace(wrapper)
      wrapper.add_child(table)
    end

    doc.to_html.strip
  end

  BULLET_CHARS = "•●■◦▪\u2022\u2023\u25E6\u2043\u2219"
  BULLET_TEXT_PATTERN = /\A\s*[#{BULLET_CHARS}–—]\s*/
  BULLET_HTML_PATTERN = /\A\s*[#{BULLET_CHARS}–—]\s*/

  def self.bullet_item?(node)
    node.name == "p" && node.text.strip.match?(BULLET_TEXT_PATTERN)
  end

  # Strip bullet character from a node's content (handles text nodes inside HTML)
  def self.strip_bullet(node)
    # Walk to the first text node and strip the bullet from it
    node.traverse do |child|
      next unless child.text?
      if child.content.match?(BULLET_TEXT_PATTERN)
        child.content = child.content.sub(BULLET_TEXT_PATTERN, "")
        break
      end
    end
  end

  # Find consecutive <p> tags that start with bullet chars and wrap them in <ul><li>
  def self.group_bullet_points(doc)
    nodes = doc.children.to_a
    i = 0

    while i < nodes.length
      node = nodes[i]

      if bullet_item?(node)
        # Collect consecutive bullet <p> tags
        bullet_nodes = [ node ]
        j = i + 1
        while j < nodes.length && bullet_item?(nodes[j])
          bullet_nodes << nodes[j]
          j += 1
        end

        # Build <ul> with <li> items
        ul = doc.document.create_element("ul")
        bullet_nodes.each do |bp|
          li = doc.document.create_element("li")
          li.inner_html = bp.inner_html
          strip_bullet(li)
          ul.add_child(li)
        end

        # Replace first bullet node with <ul>, remove the rest
        bullet_nodes.first.replace(ul)
        bullet_nodes[1..].each(&:remove)

        nodes = doc.children.to_a
      end

      i += 1
    end
  end

  def self.collapsible?(title)
    COLLAPSIBLE_PATTERNS.any? { |pattern| title.match?(pattern) }
  end
end
