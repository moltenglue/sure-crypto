import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    connected: { type: Boolean, default: false },
    apiKey: String,
  };

  static targets = ["password", "loading", "netWorth", "balances"];

  connect() {
    if (this.connectedValue) {
      this.fetchBalances();
    }
  }

  async connect(event) {
    event.preventDefault();
    this.loadingTarget.classList.remove("hidden");
    this.passwordTarget.disabled = true;

    try {
      const response = await fetch("/api/v1/rotki/connect", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        },
        body: JSON.stringify({ password: this.passwordTarget.value }),
      });

      if (response.ok) {
        this.connectedValue = true;
        this.element.classList.remove("connect-form");
        this.element.classList.add("connected-view");
        this.fetchBalances();
      } else {
        const error = await response.json();
        alert(error.message || "Failed to connect to Rotki");
      }
    } catch (error) {
      console.error("Rotki connection error:", error);
      alert("Failed to connect to Rotki");
    } finally {
      this.loadingTarget.classList.add("hidden");
      this.passwordTarget.disabled = false;
    }
  }

  async fetchBalances() {
    try {
      const response = await fetch("/api/v1/rotki/balances", {
        headers: {
          "X-Api-Key": this.apiKeyValue,
        },
      });

      if (response.ok) {
        const data = await response.json();
        this.updateDisplay(data);
      }
    } catch (error) {
      console.error("Failed to fetch Rotki balances:", error);
    }
  }

  escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  updateDisplay(data) {
    if (this.hasNetWorthTarget) {
      this.netWorthTarget.textContent = this.formatCurrency(data.net_worth);
    }

    if (this.hasBalancesTarget && data.balances?.total) {
      this.balancesTarget.innerHTML = data.balances.total
        .map(
          (balance) => `
          <div class="balance-row flex justify-between py-2">
            <span class="symbol font-medium">${this.escapeHtml(balance.asset_symbol)}</span>
            <span class="quantity">${this.escapeHtml(balance.quantity)}</span>
            <span class="value">${this.formatCurrency(balance.converted_value)}</span>
          </div>
        `
        )
        .join("");
    }
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(value || 0);
  }
}
