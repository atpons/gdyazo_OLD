#!/usr/bin/env ruby

require 'net/http'
require 'dotenv'

Dotenv.load

# get id
user = IO.popen("whoami", "r+").gets.chomp
program = ARGV[0].to_s
idfile = "/Users/#{user}/Library/Gyazo/id"
old_idfile = File.dirname(program) + "/gyazo.app/Contents/Resources/id"

id = ''
if File.exist?(idfile) then
  id = File.read(idfile).chomp
elsif File.exist?(old_idfile) then
  id = File.read(old_idfile).chomp
end

# capture png file
tmpfile = "/tmp/image_upload#{$$}.png"
imagefile = ARGV[1]

if imagefile && File.exist?(imagefile) then
  system "sips -s format png \"#{imagefile}\" --out \"#{tmpfile}\""
else
  system "screencapture -i \"#{tmpfile}\""
  if File.exist?(tmpfile) then
    system "sips -d profile --deleteColorManagementProperties \"#{tmpfile}\""  
    dpiWidth    = `sips -g dpiWidth "#{tmpfile}" | awk '/:/ {print $2}'`
    dpiHeight   = `sips -g dpiHeight "#{tmpfile}" | awk '/:/ {print $2}'`
    pixelWidth  = `sips -g pixelWidth "#{tmpfile}" | awk '/:/ {print $2}'`
    pixelHeight = `sips -g pixelHeight "#{tmpfile}" | awk '/:/ {print $2}'`
    if (dpiWidth.to_f > 72.0 and dpiHeight.to_f > 72.0) then
        width  =  pixelWidth.to_f * 72.0 / dpiWidth.to_f
        height =  pixelHeight.to_f* 72.0 / dpiHeight.to_f
        system "sips -s dpiWidth 72 -s dpiHeight 72 -z #{height} #{width} \"#{tmpfile}\""
    end
  end
end

if !File.exist?(tmpfile) then
  exit
end

imagedata = File.read(tmpfile)
File.delete(tmpfile)

# upload
boundary = '----BOUNDARYBOUNDARY----'

HOST = ENV["HOST"] #'localhost'
CGI = ENV["CGI"] # '/upload.cgi'
UA   = ENV["UA"] #'Gyazo/2.0'

data = <<EOF
--#{boundary}\r
content-disposition: form-data; name="id"\r
\r
#{id}\r
--#{boundary}\r
content-disposition: form-data; name="imagedata"; filename="gyazo.com"\r
\r
#{imagedata}\r
--#{boundary}--\r
EOF

header ={
  'Content-Length' => data.length.to_s,
  'Content-type' => "multipart/form-data; boundary=#{boundary}",
  'User-Agent' => UA
}

Net::HTTP.start(HOST,ENV["PORT"]){|http|
  res = http.post(CGI,data,header)
  url = res.response.body
  IO.popen("pbcopy","r+"){|io|
    io.write url
    io.close
  }
  system "open #{url}"

  # save id
  newid = res.response['X-Gyazo-Id']
  if newid and newid != "" then
    if !File.exist?(File.dirname(idfile)) then
      Dir.mkdir(File.dirname(idfile))
    end
    if File.exist?(idfile) then
      File.rename(idfile, idfile+Time.new.strftime("_%Y%m%d%H%M%S.bak"))
    end
    File.open(idfile,"w").print(newid)
    if File.exist?(old_idfile) then
      File.delete(old_idfile)
    end
  end
}
