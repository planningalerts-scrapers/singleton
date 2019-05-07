require 'scraperwiki'
require 'mechanize'

url = 'http://portal.singleton.nsw.gov.au/eplanning/Pages/XC.Track/SearchApplication.aspx?as=n&d=thisweek&k=LodgementDate&t=8'

agent = Mechanize.new
page = agent.get(url)

page.search('.result').each do |application|
  # Skip multiple addresses
  next unless application.search("strong").select{|x|x.inner_text != "Approved"}.length == 1

  date_received = application.children[6].inner_text.split("\r\n").last.strip

  application_id = application.search('a').first['href'].split('?id=').last.strip
  info_url = "http://portal.singleton.nsw.gov.au/eplanning/pages/XC.Track/SearchApplication.aspx?id=#{application_id}"
  record = {
    "council_reference" => application.search('a').first.inner_text,
    "description" => application.children[4].inner_text.strip.gsub('DEVELOPMENT APPLICATION        - ', ''),
    "date_received" => Date.parse(date_received, 'd/m/Y').to_s,
    # TODO: There can be multiple addresses per application
    "address" => application.search("strong").first.inner_text.strip,
    "date_scraped" => Date.today.to_s,
    "info_url" => info_url,
    # Can't find a specific url for commenting on applications.
    "comment_url" => info_url,
  }
  # DA03NY1 appears to be the event code for putting this application on exhibition
  e = application.search("Event EventCode").find{|e| e.inner_text.strip == "DA03NY1"}
  if e
    record["on_notice_from"] = Date.parse(e.parent.at("LodgementDate").inner_text).to_s
    record["on_notice_to"] = Date.parse(e.parent.at("DateDue").inner_text).to_s
  end

  ScraperWiki.save_sqlite(['council_reference'], record)
end
