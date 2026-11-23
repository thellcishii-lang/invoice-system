require "test_helper"

class RecurringDocumentsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when unauthenticated" do
    get recurring_documents_path

    assert_redirected_to new_session_path
  end

  test "index shows only own tenant schedules" do
    sign_in_as(users(:one))

    get recurring_documents_path

    assert_response :success
    assert_match documents(:invoice_one).number, response.body
    assert_no_match ERB::Util.html_escape(documents(:invoice_two).number), response.body
  end

  test "new from an invoice pre-fills the template and its issue day" do
    sign_in_as(users(:one))

    get new_recurring_document_path(template_document_id: documents(:invoice_one).id)

    assert_response :success
    assert_match documents(:invoice_one).number, response.body
  end

  test "creates a schedule from a template invoice" do
    sign_in_as(users(:one))

    assert_difference("RecurringDocument.count", 1) do
      post recurring_documents_path, params: { recurring_document: {
        template_document_id: documents(:invoice_one).id, day_of_month: 15, send_method: "email"
      } }
    end

    assert_redirected_to recurring_documents_path
    schedule = RecurringDocument.order(:id).last
    assert_equal tenants(:one), schedule.tenant
    assert_equal documents(:invoice_one), schedule.template_document
    assert_equal documents(:invoice_one).client, schedule.client
    assert_equal 15, schedule.day_of_month
    assert_equal "email", schedule.send_method
    assert schedule.active?
    assert_equal 15, schedule.next_run_date.day
    assert schedule.next_run_date >= Date.current
  end

  test "rejects a day_of_month beyond 28" do
    sign_in_as(users(:one))

    assert_no_difference("RecurringDocument.count") do
      post recurring_documents_path, params: { recurring_document: {
        template_document_id: documents(:invoice_one).id, day_of_month: 29
      } }
    end

    assert_response :unprocessable_entity
  end

  test "cannot create a schedule from another tenant's invoice" do
    sign_in_as(users(:one))

    assert_no_difference("RecurringDocument.count") do
      post recurring_documents_path, params: { recurring_document: {
        template_document_id: documents(:invoice_two).id, day_of_month: 15
      } }
    end

    assert_response :unprocessable_entity
  end

  test "updates the day, send method and active flags" do
    sign_in_as(users(:one))
    schedule = recurring_documents(:monthly_invoice)

    patch recurring_document_path(schedule), params: { recurring_document: {
      day_of_month: 20, send_method: "fax", active: "0"
    } }

    assert_redirected_to recurring_documents_path
    schedule.reload
    assert_equal 20, schedule.day_of_month
    assert_equal "fax", schedule.send_method
    assert_not schedule.active?
    assert_equal 20, schedule.next_run_date.day
  end

  test "destroys a schedule" do
    sign_in_as(users(:one))

    assert_difference("RecurringDocument.count", -1) do
      delete recurring_document_path(recurring_documents(:monthly_invoice))
    end

    assert_redirected_to recurring_documents_path
  end

  test "cannot edit another tenant's schedule" do
    sign_in_as(users(:one))

    get edit_recurring_document_path(recurring_documents(:other_tenant_schedule))

    assert_response :not_found
  end

  test "cannot update another tenant's schedule" do
    sign_in_as(users(:one))

    patch recurring_document_path(recurring_documents(:other_tenant_schedule)), params: { recurring_document: { day_of_month: 1 } }

    assert_response :not_found
    assert_equal 15, recurring_documents(:other_tenant_schedule).reload.day_of_month
  end

  test "cannot destroy another tenant's schedule" do
    sign_in_as(users(:one))

    assert_no_difference("RecurringDocument.count") do
      delete recurring_document_path(recurring_documents(:other_tenant_schedule))
    end

    assert_response :not_found
  end

  test "document page offers to make an invoice recurring" do
    sign_in_as(users(:one))

    get document_path(documents(:invoice_one))

    assert_response :success
    assert_match "定期請求にする", response.body
  end
end
