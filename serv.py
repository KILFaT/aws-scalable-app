#!/usr/bin/python
from BaseHTTPServer import BaseHTTPRequestHandler,HTTPServer
import requests

PORT_NUMBER = 80

#This class will handles any incoming request from
#the browser 
class myHandler(BaseHTTPRequestHandler):

        #Handler for the GET requests
        def do_GET(self):		
    		f = open('00000001.png', 'wb')
    		f.write(requests.get("").content)
    		f.close()		
                self.send_response(200)
                self.send_header('Content-type','text/html')
                self.end_headers()
                # Send the html message
                self.wfile.write("Hello World !")
		data_uri = open('00000001.png', 'rb').read().encode('base64').replace('\n', '')
		img_tag = '<img src="data:image/png;base64,{0}">'.format(data_uri)
  		self.wfile.write(img_tag)
                return
try:

       #Create a web server and define the handler to manage the
        #incoming request
        server = HTTPServer(('', PORT_NUMBER), myHandler)
        print 'Started httpserver on port ' , PORT_NUMBER

        #Wait forever for incoming htto requests
        server.serve_forever()

except KeyboardInterrupt:
        print '^C received, shutting down the web server'
        server.socket.close()
