# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

# Function to clean and format zipcode to a 5-digit string
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

# Function to fetch legislators by zipcode using Google Civic Information API
def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key')
  begin
    civic_info.representative_info_by_address(
      address: zip, levels: 'country', roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

# Function to save thank you letter to an output file
def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output') # Create output directory if it doesn't exist
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

# Function to clean and format phone numbers
def clean_phone(phone)
  phone.gsub!(/[\s.()-]/, '') # Remove spaces, dots, parentheses, and dashes
  # Remove country code if 11 digits and starts with 1
  phone = phone.length == 11 && phone[0].to_i == 1 ? phone[1..] : phone
  phone.length == 10 ? phone : 'Bad Number' # Return phone if 10 digits, otherwise 'Bad Number'
end

# Function to parse registration date and time
def get_registration_datetime(reg_datetime)
  DateTime.strptime(reg_datetime, '%m/%d/%y %H:%M')
end

# Function to get the most frequent occurrence in an array
def get_frequency(time)
  time.tally.values.max
end

# Function to get the peak time based on frequency
def get_peak_time(time)
  time.tally.select { |_k, v| v == get_frequency(time) }.keys
end

# Function to format pluralization
def pluralize(array)
  array.length > 1 ? ['s', array.join(', ')] : ['', array[0]]
end

puts 'EventManager initialized'

# Open the CSV file with event attendees
contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

# Read the template letter
template_letter = File.read('form_letter.html')
erb_template = ERB.new(template_letter)

# Arrays to store hours and days of registration
hours = []
days = []

# Iterate through each row in the CSV
contents.each do |row|
  id = row[0] # Retrieve row number
  name = row[:first_name] # Retrieve first name
  zipcode = clean_zipcode(row[:zipcode]) # Retrieve zipcode
  legislators = legislators_by_zipcode(zipcode) # Retrieve legislator
  form_letter = erb_template.result(binding) # Set up thank you letter template
  clean_phone(row[:homephone]) # Retrieve cleaned phone number

  # Retrieve registration date
  reg_datetime = get_registration_datetime(row[:regdate])
  hours << reg_datetime.hour # Store the registration hours
  days << Date::DAYNAMES[reg_datetime.wday] # Store the registration days

  save_thank_you_letter(id, form_letter) # Print thank you letter
end

# Calculate and print the peak registration hours
peak_hours = get_peak_time(hours)
puts "Most people registered in the hour#{pluralize(peak_hours)[0]} of #{pluralize(peak_hours)[1]}."

# Calculate and print the peak registration days
peak_days = get_peak_time(days)
puts "Most people registered on the day#{pluralize(peak_days)[0]} of #{pluralize(peak_days)[1]}."
