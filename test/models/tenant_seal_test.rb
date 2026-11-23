require "test_helper"

class TenantSealTest < ActiveSupport::TestCase
  def uploaded_png
    ActionDispatch::Http::UploadedFile.new(
      tempfile: File.new(Rails.root.join("test/fixtures/files/seal.png")),
      filename: "seal.png", type: "image/png"
    )
  end

  test "attach_seal stores a PNG as base64 with its content type" do
    tenant = tenants(:one)

    assert tenant.attach_seal(uploaded_png)
    assert tenant.seal_image?
    assert_equal "image/png", tenant.seal_image_content_type
    assert tenant.seal_image_data_uri.start_with?("data:image/png;base64,")
  end

  test "attach_seal rejects a non-image file" do
    tenant = tenants(:one)
    bad = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.new(Rails.root.join("test/fixtures/files/seal.png")),
      filename: "seal.txt", type: "text/plain"
    )

    assert_not tenant.attach_seal(bad)
    assert_not tenant.seal_image?
    assert tenant.errors[:seal_image].any?
  end

  test "remove_seal clears the stored image" do
    tenant = tenants(:one)
    tenant.attach_seal(uploaded_png)

    tenant.remove_seal

    assert_not tenant.reload.seal_image?
    assert_nil tenant.seal_image_data_uri
  end
end
