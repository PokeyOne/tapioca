# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `ar_transaction_changes` gem.
# Please instead update this file by running `bin/tapioca gem ar_transaction_changes`.

# typed: true

module ArTransactionChanges
  def _run_commit_callbacks; end
  def _run_rollback_callbacks; end
  def _write_attribute(attr_name, value); end
  def transaction_changed_attributes; end
  def write_attribute(attr_name, value); end

  private

  def _read_attribute_for_transaction(attr_name); end
  def _store_transaction_changed_attributes(attr_name); end
end

ArTransactionChanges::VERSION = T.let(T.unsafe(nil), String)