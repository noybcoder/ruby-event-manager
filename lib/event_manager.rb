require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key')

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone(phone)
  phone.gsub!(/[\s\.()-]/, '')
  phone = phone.length == 11 && phone[0].to_i == 1? phone[1..]: phone
  phone.length == 10? phone: 'Bad Number'
end

def get_registration_datetime(reg_datetime)
  DateTime.strptime(reg_datetime, '%m/%d/%y %H:%M')
end

puts 'EventManager initialized'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.html')
erb_template = ERB.new(template_letter)

hours = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  phone = clean_phone(row[:homephone])

  reg_datetime = get_registration_datetime(row[:regdate])
  hours << reg_datetime.hour

  # save_thank_you_letter(id, form_letter)
  puts "#{reg_datetime}"
end

p hours.tally.sort_by { |k, v| -v}
