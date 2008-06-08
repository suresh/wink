xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title   @title || wink.title || wink.author
  xml.link    "rel" => "self", "href" => request.url
  xml.link    "rel" => "alternate", "href" => request.url.sub(/feed$/, '')
  xml.id      request.url
  xml.updated @entries.first.updated_at.iso8601 if @entries.any?
  xml.author  { xml.name wink.author }
  @entries.each do |@entry|
    xml.entry do
      xml.title @entry.title
      xml.link "rel" => "alternate", "href" => h(entry_url(@entry))
      xml.id entry_global_id
      xml.published @entry.created_at.iso8601
      xml.updated @entry.created_at.iso8601
      xml.author { xml.name wink.author }
      xml.summary entry_summary, "type" => "html"
      xml.content entry_body, "type" => "html" if @entry.body?
    end
  end
end
