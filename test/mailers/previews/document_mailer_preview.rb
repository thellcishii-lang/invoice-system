# Preview all emails at http://localhost:3000/rails/mailers/document_mailer
class DocumentMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/document_mailer/document_email
  def document_email
    document = Document.where(kind: "invoice").first || Document.first
    DocumentMailer.document_email(
      document: document,
      recipient_email: document.client.email || "client@example.com",
      token: document.public_link_token
    )
  end
end
