# require 'mechanize'
require 'scraperwiki'
require 'capybara/poltergeist'

Capybara.javascript_driver = :poltergeist
@options = { js_errors: false, timeout: 1800, phantomjs_logger: StringIO.new, logger: nil, phantomjs_options: ['--load-images=no', '--ignore-ssl-errors=yes'] }
@blacklist = ["https://maxcdn.bootstrapcdn.com/", "https://www.tenders.vic.gov.au/tenders/res/" ]

def store_non_duplicate record, id_field, table='data'
  if (ScraperWiki.select("* from #{table} where `#{id_field}`='#{record[id_field]}'").empty? rescue true)
    puts "Storing #{record[id_field]} in #{table}"
    ScraperWiki.save_sqlite(["#{id_field}"], record, table_name=table)
  else
    puts "Skipping already saved record #{record[id_field]}"
  end
end

def check_store id_value, id_field, table='data'
  if (ScraperWiki.select("* from #{table} where `#{id_field}`='#{id_value}'").empty? rescue true)
    false
  else
    true
  end
end

def get_from_store id_value, id_field, table='data'
  ScraperWiki.select("* from #{table} where `#{id_field}`='#{id_value}'")
end




ContractType = []
def ContractType.where(x)
  ContractType
end
ContractValueType = []
def ContractValueType.where(x)
  ContractValueType
end
def ContractValueType.all()
  ContractValueType
end
ContractStatus = []
def ContractStatus.where(x)
  ContractStatus
end
def ContractStatus.all()
  ContractStatus
end
Unspsc = []
def Unspsc.all()
  Unspsc
end

def lookup_contract_unspsc text
  Unspsc.all.each do |unspsc_category|
    if text.include?(unspsc_category.unspsc_name)
      return unspsc_category.unspsc_code
    end
  end
  0
end


  def lookup_contract_status text
    con_status = ContractStatus.where(name: text).first
    if con_status
      con_status.id
    else
      0
    end
  end

  def lookup_contract_status_name status_id
    status_type = ContractStatus.where(id: status_id).first
    if status_type
      status_type.name
    else
      ""
    end
  end


  def lookup_value_type text
    value_type = 0
    ContractValueType.all.each do |value_type|
      if text.include? value_type.type_description
        value_type = value_type.id
        break
      end
    end
    value_type
  end


  def lookup_contract_type_name type_id
    con_type = ContractType.where(id: type_id).first
    if con_type
      con_type.name
    else
      ""
    end
  end

  def lookup_contract_type text
    con_type = ContractType.where(name: text).first
    if con_type
      con_type.id
    else
      0
    end
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


  def extract_contract_data text, contract_index, print=false
    gov_entity = find_between(text, "Public Body:", "Contract Number:")
    gov_entity_contract_numb = find_between(text, "Contract Number:","Title:")
    contract_title = find_between(text, "Title:","Type of Contract:")
    contract_type = find_between(text, "Type of Contract:","Total Value of the Contract:")
    value_string = find_between(text, "Total Value of the Contract:","Start Date:")
    value_type = find_between(value_string,"(",")")
    contract_value = (value_string.gsub(",","").gsub("$","").to_f).to_i
    begin
      contract_start = Date.parse(find_between(text, "Start Date:","Expiry Date:"))
    rescue
      contract_start = Date.parse("11/10/1900")
    end
    begin
      contract_end = Date.parse(find_between(text, "Expiry Date:","Status:"))
    rescue
      contract_end = Date.parse("11/10/1900")
    end
    contract_status = find_between(text, "Status:", "UNSPSC :")
    begin
      contract_unspsc1 = find_between(text, "UNSPSC :", "Description")
    rescue
      contract_unspsc1 = find_between(text, "UNSPSC 1:", "Description")
      contract_unspsc2 = find_between(text, "UNSPSC 2:", "Description")
    end
    contract_details = find_between(text, "Description", "Agency Contact Details")
    agency_person = find_between(text, "Contact Person:", "Contact for factual information purposes")
    agency_phone = find_between(text, "Contact Number:", "Email Address:") # check for contact # existance
    agency_email = find_between(text, "Email Address:", "Supplier Information")
    supplier_name = find_between(text, "Supplier Name:", "ABN:")
    supplier_abn = find_between(text, "ABN:", "ACN:")
    if text.include?("DUNS #:")
      supplier_acn = find_between(text, "ACN:", "DUNS #:")
    else
      supplier_acn = find_between(text, "ACN:", "Address:")
    end
    chunk = find_between(text, "Email Address:", "State:")
    street = find_between(chunk, "Address:", "Suburb:")
    suburb = find_between(text, "Suburb:", "State:")
    state = find_between(text, "State:", "Postcode:")
    post_code = find_between(text, "Postcode:", "Email Address:")
    supplier_address = "#{street}, #{suburb}, #{state} #{post_code}"
    supplier_email = find_between(text, "Email Address:", "State Government of Victoria")
    { department_id: lookup_agency_id(gov_entity),
      contract_number: gov_entity_contract_numb,
      contract_title: contract_title,
      contract_type: lookup_contract_type(contract_type),
      contract_value: contract_value,
      value_type_index: lookup_value_type(value_string),
      contract_start: contract_start,
      contract_end: contract_end,
      contract_status: lookup_contract_status(contract_status),
      contract_unspsc: lookup_contract_unspsc(contract_unspsc1),
      contract_details: contract_details,
      supplier_name: supplier_name,
      supplier_abn: supplier_abn,
      supplier_acn: supplier_acn,
      agency_person: agency_person,
      agency_phone: agency_phone,
      agency_email: agency_email,
      supplier_address: supplier_address,
      vt_identifier: contract_index
    }
  end



def prepare_session
  options = { js_errors: false, timeout: 1800, phantomjs_logger: StringIO.new, logger: nil, phantomjs_options: ['--load-images=no', '--ignore-ssl-errors=yes', '--ssl-protocol=any'] }
  session = Capybara::Session.new(:poltergeist, options)
  session.driver.browser.url_blacklist = ["https://maxcdn.bootstrapcdn.com/", "https://www.tenders.vic.gov.au/tenders/res/"]
  session.driver.browser.js_errors = false
  session.driver.timeout = 1800
  session
end

  def check_department_reference department_string, agency_index
    is_present = check_store agency_index, "agency_index", table='data'
    if not is_present
      puts "Dynamicaly creating '#{department_string}' with ref #{agency_index}"
      store_non_duplicate ({"agency_index" => "#{agency_index}", "agency_name" => "#{department_string}"}), "agency_index", table='agencies'
    end
  end

  def clean_department_link_text text
    text[0..(text.index("(")-2)]
  end

  def lookup_agency_id department_text
    matching_agency = get_from_store department_text, "agency_name", table='agencies'
    if matching_agency
      return matching_agency[0]["agency_name"]
    end
    puts "could not find agency '#{department_text}'"
    0
  end

  def lookup_agency_name department_id
    matching_agency = get_from_store department_id, "agency_index", table='agencies'
    if matching_agency
      matching_agency.name
    else
      ""
    end
  end




print "\n ∵ TendersVIC Scrape @ #{Time.now} ∵\n"

session = prepare_session
session.visit "https://www.tenders.vic.gov.au/tenders/contract/list.do?action=contract-view"
department_indexes_to_scrape = []
department_links = session.find_all "a#MSG2"
department_links.each do |department_link|
  department_id = find_between department_link[:href], "issuingBusinessId=", "&"
  department_string = clean_department_link_text department_link[:text]
  check_department_reference department_string, department_id
  @saved_date = department_link[:href][-10..-1]
  department_indexes_to_scrape.push(department_id)
  # puts "Department (#{department_id}) - #{department_link[:text]}"
  break if department_link.text.include?("Department of Education and Training") # Stop after third dep DEBUG
end
session.driver.quit

  contract_indexes_to_scrape = []
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
        contract_indexes_to_scrape.push vt_reference
          # break # stop after first contract DEBUG
      end
      current_page = department_session.text
      department_session.driver.quit
      page_number += 1
    end
    print "\n"
  end







puts "🖻: #{contract_indexes_to_scrape}"

contract_session = prepare_session()
Capybara.reset_sessions!
contract_indexes_to_scrape.to_set.each do |contract_index|
  contract_session.visit "http://www.tenders.vic.gov.au/tenders/contract/view.do?id=#{contract_index}"
  contract_data = extract_contract_data(contract_session.text, contract_index, print)
  contract = {
      'vt_contract_number' => contract_data[:contract_number],
      'vt_status_id' => contract_data[:contract_status],
      'vt_title' => contract_data[:contract_title],
      'vt_start_date' => contract_data[:contract_start],
      'vt_end_date' => contract_data[:contract_end],
      'vt_total_value' => contract_data[:contract_value],
      'vt_department_id' => contract_data[:department_id],
      'vt_contract_type_id' => contract_data[:contract_type],
      'vt_value_type_id' => contract_data[:value_type_index],
      'vt_unspc_id' => contract_data[:contract_unspsc],
      'vt_contract_description' => contract_data[:contract_details],
      'vt_agency_person' => contract_data[:agency_person],
      'vt_agency_phone' => contract_data[:agency_phone],
      'vt_agency_email' => contract_data[:agency_email],
      'vt_supplier_name' => contract_data[:supplier_name],
      'vt_supplier_abn' => contract_data[:supplier_abn],
      'vt_supplier_acn' => contract_data[:supplier_acn],
      'vt_supplier_address' => contract_data[:supplier_address],
      'project_id' => contract_data[:vt_identifier]
  }
  store_non_duplicate contract, 'vt_contract_number'
end
contract_session.driver.quit
print "\n ∴ Completed Scraping @ #{Time.now} ∴\n"




# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".
