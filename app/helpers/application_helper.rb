# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def format_time(time, format = :iso)
    case format
    when :human
      remove_leading_zeros(
        Time.now > time + 24.hours ?
          time.strftime('on %b %d') :
          time.strftime('at %H:%M'))
    when :iso
      time.strftime('%Y-%m-%d %H:%M:%S')
    when :iso_date
      time.strftime('%Y-%m-%d')
    when :verbose
      remove_leading_zeros(time.strftime('%I:%M %p on %B %d, %Y'))
    when :round_trip_local
      time.strftime('%Y-%m-%dT%H:%M:%S.0000000-00:00') # yyyy'-'MM'-'dd'T'HH':'mm':'ss.fffffffK)
    else
      raise "Unknown time format #{format.inspect}"
    end
  end
  
  # surely there's a way to do this with strftime, but I couldn't find it... - jss
  def remove_leading_zeros(string)
    string.gsub(/(^| |,)0+/, '\1')
  end
  
  def setting_row(label, value, help = '&nbsp;')
    <<-EOL
    <tr>
      <td class='label'>#{label} :</td>
      <td>#{value}</td>
      <td class='help'>#{help}</td>
    </tr>
    EOL
  end

end
