CREATE DATABASE mail;
CREATE USER 'mail'@'localhost' identified by '123456789';
GRANT ALL on mail.* to 'mail'@'localhost';
FLUSH PRIVILEGES;
