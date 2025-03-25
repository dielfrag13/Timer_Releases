Windows Installation instructions:

1. download both files into the same download directory (the installer will ask you what you'd like to use for the installation directory)
2. run server_installer.ps1. depending on your execution policy, you may need to run "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force" first
3. Proceed through the interactive installation script
4. run the generated start_server.ps1 script in the installation folder

Note 1: these instructions will enable the app server over HTTP. HTTPS will come in a future update.

To change certain settings, you will need to access [installation directory]/timer_server/settings.py. 

Note 2: Currently, the server is configured to allow hosting under the following hosts:
  * localhost
  * 127.0.0.1
  * 0.0.0.0

If your Windows server is running and accessible via a specific internal DNS hostname, you will probably need to add this to the ALLOWED_HOSTS setting in the above mentioned configuration file.

Note 3: Please set the TIME_ZONE setting in the above mentioned configuration file to your preferred time zone. 



