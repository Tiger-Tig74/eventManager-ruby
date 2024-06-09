# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
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
  phone = phone.scan(/\b\d+\b/).join('')
  if phone.size < 10 || phone.size > 11
    'Bad number'
  elsif phone.size == 10
    phone
  elsif phone.size == 11
    if phone.start_with?('1')
      phone.sub(/\d/, '')
    else
      'Bad number'
    end
  end
end

hourly_counts = Hash.new(0)
daily_counts = Hash.new(0)
def process_registration_time(time, hourly_counts, daily_counts)
  time = Time.strptime(time, '%m/%d/%y %H:%M')
  hour = time.hour
  hourly_counts[hour] += 1
  day_of_week = time.wday
  daily_counts[day_of_week] += 1
end

def peak_hours(hourly_counts)
  peak_hours = hourly_counts.select { |_hour, count| count == hourly_counts.values.max }
  peak_hours.keys.map { |hour| "#{format('%02d', hour)}:00" }.join(', ')
end

def peak_days(daily_counts)
  peak_days = daily_counts.select { |_day, count| count == daily_counts.values.max }
  day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  peak_days.keys.map { |day| day_names[day] }.join(', ')
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone = clean_phone(row[:homephone])
  process_registration_time(row[1], hourly_counts, daily_counts)
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  puts "Name: #{name}, Phone: #{phone}"
end

puts "Peak registration hours: #{peak_hours(hourly_counts)}"
puts "Peak registration days: #{peak_days(daily_counts)}"
