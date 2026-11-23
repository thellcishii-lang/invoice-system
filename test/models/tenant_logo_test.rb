require "test_helper"

class TenantLogoTest < ActiveSupport::TestCase
  def uploaded_png
    ActionDispatch::Http::UploadedFile.new(
      tempfile: File.new(Rails.root.join("test/fixtures/files/seal.png")),
      filename: "logo.png", type: "image/png"
    )
  end

  test "attach_logo stores a PNG and exposes placement defaults" do
    tenant = tenants(:one)

    assert tenant.attach_logo(uploaded_png)
    assert tenant.logo_image?
    assert tenant.logo_image_data_uri.start_with?("data:image/png;base64,")
    assert_equal "top", tenant.logo_placement_value
    assert_equal "left", tenant.logo_alignment_value
  end

  test "attach_logo rejects a non-image file" do
    tenant = tenants(:one)
    bad = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.new(Rails.root.join("test/fixtures/files/seal.png")),
      filename: "logo.txt", type: "text/plain"
    )

    assert_not tenant.attach_logo(bad)
    assert_not tenant.logo_image?
  end

  test "remove_logo clears the stored image" do
    tenant = tenants(:one)
    tenant.attach_logo(uploaded_png)

    tenant.remove_logo

    assert_not tenant.reload.logo_image?
  end
end
