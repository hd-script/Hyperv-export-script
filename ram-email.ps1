$smtpServer = "mailserver.host.name"
$Username = "your@mail.com"
$Password = "password"
$msg = new-object Net.Mail.MailMessage
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
$msg.From = "sender@mail.com"
$msg.To.Add("recipient@mail.com")
