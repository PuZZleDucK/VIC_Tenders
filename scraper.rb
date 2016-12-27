# require 'mechanize'
require 'scraperwiki'
require 'capybara/poltergeist'

# agent = Mechanize.new
Capybara.javascript_driver = :poltergeist
@options = { js_errors: false, timeout: 1800, phantomjs_logger: StringIO.new, logger: nil, phantomjs_options: ['--load-images=no', '--ignore-ssl-errors=yes'] }
@blacklist = ["https://maxcdn.bootstrapcdn.com/", "https://www.tenders.vic.gov.au/tenders/res/" ]

Department = []
def Department.where(x)
  x
end

def find_between(text, pre_string, post_string)
  matches = text.match(/#{pre_string}(.*?)#{post_string}/)
  if matches && matches.length > 1
    matches[1].strip
  else
    puts "Match failed!"
    puts "nothing between '#{pre_string}' & '#{post_string}'"
    puts "in #{text}"
    ""
  end
end

# # Read in a page
# page = agent.get("http://foo.com")

def prepare_session
  options = { js_errors: false, timeout: 1800, phantomjs_logger: StringIO.new, logger: nil, phantomjs_options: ['--load-images=no', '--ignore-ssl-errors=yes', '--ssl-protocol=any'] }
  session = Capybara::Session.new(:poltergeist, options)
  session.driver.browser.url_blacklist = ["https://maxcdn.bootstrapcdn.com/", "https://www.tenders.vic.gov.au/tenders/res/"]
  session.driver.browser.js_errors = false
  session.driver.timeout = 1800
  session
end

def scrape_contract_ids department_indexes_to_scrape
  contract_indexes = []
  department_indexes_to_scrape.each do |department_index|
    print "Agency: #{department_index}: "
    page_number = 1
    previous_page = ""
    current_page = "not blank"
    while previous_page != current_page
      previous_page = current_page
      department_session = prepare_session
      department_url = "https://www.tenders.vic.gov.au/tenders/contract/list.do?showSearch=false&action=contract-search-submit&issuingBusinessId=#{department_index}&issuingBusinessIdForSort=#{department_index}&pageNum=#{page_number}&awardDateFromString=#{@saved_date}"
      department_session.visit department_url
      contract_links = department_session.find_all "a#MSG2"
      print "\n   § #{page_number}: "
      contract_links.each do |contract_link|
        vt_reference = contract_link["href"].to_s[59..63]
        print "."
        contract_indexes.push vt_reference
          # break # stop after first contract DEBUG
      end
      current_page = department_session.text
      department_session.driver.quit
      page_number += 1
    end
    print "\n"
  end
  contract_indexes
end

  def check_department_reference department_string, department_index
    match = Department.where(vt_number: department_index).first
    if !match
      Department.all.each do |department| # fallback to string matching
        if department_string.downcase.gsub(" ","").include? department.name.downcase.gsub(" ","")
          if department.vt_number == 0 # dynamicaly add ref #
            department.vt_number = department_index
            department.save
            puts ":: UPDATED DEPARTMENT REF: #{department.name} <== #{department_index}::"
          end
        end
      end
      puts "Dynamicaly creating '#{department_string}' with ref #{department_index}"
      Department.create(name: department_string, short_name: "Ref-#{department_index}", vt_number: department_index)
    end
  end

  def clean_department_link_text text
    text[0..(text.index("(")-2)]
  end

  def lookup_department_id department_text, print=false
      Department.all.each do |department|
        if department_text.downcase.gsub(" ","").include? department.name.downcase.gsub(" ","")
          return department.vt_number
        end
      end
      if print then puts "could not find agency '#{department_text}'" end
      0
  end

  def lookup_department_short_name department_id
    department = Department.where(vt_number: department_id).first
    if department
      department.short_name
    else
      ""
    end
  end

  def lookup_department_name department_id
    department = Department.where(vt_number: department_id).first
    if department
      department.name
    else
      ""
    end
  end

def scrape_department_ids department_list_url
  session = prepare_session
  session.visit department_list_url
  department_indexes_to_scrape = []
  department_links = session.find_all "a#MSG2"
  department_links.each do |department_link|
    department_id = find_between department_link[:href], "issuingBusinessId=", "&"
    department_string = clean_department_link_text department_link[:text]
    check_department_reference department_string, department_id
    @saved_date = department_link[:href][-10..-1]
    department_indexes_to_scrape.push(department_id)
    # puts "Department (#{department_id}) - #{department_link[:text]}"
      # break if department_link.text.include?("Department of Education and Training") # Stop after third dep DEBUG
  end
  session.driver.quit
  department_indexes_to_scrape
end

def scrape_for_references department_list_url
  department_indexes_to_scrape = scrape_department_ids department_list_url
  contract_indexes = scrape_contract_ids department_indexes_to_scrape
  puts "🖻: #{contract_indexes}"
  contract_indexes
end

def scrape_tenders_vic refresh=false, print=true
  print "\n ∵ TendersVIC Scrape @ #{Time.now} ∵\n"
  contract_indexes_to_scrape = scrape_for_references("https://www.tenders.vic.gov.au/tenders/contract/list.do?action=contract-view")
  contract_session = prepare_session()
  Capybara.reset_sessions!
  contract_indexes_to_scrape.to_set.each do |contract_index|
    contract_session.visit "http://www.tenders.vic.gov.au/tenders/contract/view.do?id=#{contract_index}"
    contract_data = extract_contract_data(contract_session.text, contract_index, print)
    store_or_skip(contract_data, refresh)
  end
  contract_session.driver.quit
  print "\n ∴ Completed Scraping @ #{Time.now} ∴\n"
end

scrape_tenders_vic




# # Find somehing on the page using css selectors
# p page.at('div.content')
#

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".
