class RotkiItemsController < ApplicationController
  def sync
    @rotki_item = Current.family.rotki_items.find(params[:id])

    @rotki_item.sync_later

    redirect_to settings_providers_path, notice: "Rotki sync started"
  end
end
