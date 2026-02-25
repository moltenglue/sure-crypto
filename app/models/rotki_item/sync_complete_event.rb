class RotkiItem::SyncCompleteEvent
  attr_reader :rotki_item

  def initialize(rotki_item)
    @rotki_item = rotki_item
  end

  def broadcast
    rotki_item.accounts.each do |account|
      account.broadcast_sync_complete
    end

    rotki_item.broadcast_replace_to(
      rotki_item.family,
      target: "rotki_item_#{rotki_item.id}",
      partial: "rotki_items/rotki_item",
      locals: { rotki_item: rotki_item }
    )

    rotki_item.family.broadcast_sync_complete
  end
end
