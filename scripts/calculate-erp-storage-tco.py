#!/usr/bin/env python3
"""
calculate-erp-storage-tco.py
FinOps Cost Simulator: Azure Blob Storage ERP Invoices & Orders in Spain Central.
Calculates mathematical TCO comparing Traditional All-Hot vs 4-Tier Automated Lifecycle
over statutory retention periods (6 years Código de Comercio or 10 years LGT BINs).
"""

import argparse
import sys

# Official Azure Blob Storage pricing for Spain Central (EUR / GB / month)
PRICING = {
    "LRS": {
        "Hot": 0.0184,
        "Cool": 0.0100,
        "Cold": 0.0045,
        "Archive": 0.00099,
    },
    "ZRS": {
        "Hot": 0.0230,
        "Cool": 0.0125,
        "Cold": 0.0058,
        "Archive": 0.00125,
    },
}

def calculate_tier_volumes(total_gb: float, retention_years: int):
    """
    Computes data distribution across tiers in steady state:
    Hot: 0 - 90 days (3 months)
    Cool: 91 - 365 days (9 months)
    Cold: 1 - 3 years (24 months)
    Archive: 3 to retention_years (months_remaining)
    """
    total_months = retention_years * 12
    monthly_ingest = total_gb / total_months

    hot_months = min(3, total_months)
    cool_months = max(0, min(9, total_months - hot_months))
    cold_months = max(0, min(24, total_months - hot_months - cool_months))
    archive_months = max(0, total_months - hot_months - cool_months - cold_months)

    hot_gb = hot_months * monthly_ingest
    cool_gb = cool_months * monthly_ingest
    cold_gb = cold_months * monthly_ingest
    archive_gb = archive_months * monthly_ingest

    return {
        "Hot": hot_gb,
        "Cool": cool_gb,
        "Cold": cold_gb,
        "Archive": archive_gb,
        "monthly_ingest": monthly_ingest,
    }

def print_tco_report(total_gb: float, years: int, sku: str):
    rates = PRICING[sku]
    vols = calculate_tier_volumes(total_gb, years)

    # Monthly costs at steady state
    cost_hot_baseline = total_gb * rates["Hot"]
    cost_tier_hot = vols["Hot"] * rates["Hot"]
    cost_tier_cool = vols["Cool"] * rates["Cool"]
    cost_tier_cold = vols["Cold"] * rates["Cold"]
    cost_tier_archive = vols["Archive"] * rates["Archive"]
    cost_tiered_total = cost_tier_hot + cost_tier_cool + cost_tier_cold + cost_tier_archive

    monthly_savings = cost_hot_baseline - cost_tiered_total
    percentage_savings = (monthly_savings / cost_hot_baseline) * 100

    # Cumulative total cost over lifecycle
    cumulative_hot = cost_hot_baseline * (years * 12) / 2 # linear ramp approx
    cumulative_tiered = cost_tiered_total * (years * 12) / 2
    cumulative_savings = cumulative_hot - cumulative_tiered

    print("=" * 72)
    print(f"💰 Azure Blob Storage FinOps TCO Simulation: Spain Central (Madrid)")
    print("=" * 72)
    print(f"Total Target Volume   : {total_gb:,.1f} GB ({total_gb / 1024:.2f} TB)")
    print(f"Statutory Retention   : {years} years ({years * 365} days)")
    print(f"Redundancy Model      : {sku} ({'3 Madrid Availability Zones' if sku == 'ZRS' else 'Locally Redundant'})")
    print(f"Monthly Ingestion     : ~{vols['monthly_ingest']:.2f} GB / month")
    print("-" * 72)
    print(f"{'Access Tier':<15} | {'Volume (GB)':<12} | {'Rate (€/GB/mo)':<15} | {'Monthly Cost (€)':<15}")
    print("-" * 72)
    print(f"{'Hot (0-90d)':<15} | {vols['Hot']:>10.2f} GB | {rates['Hot']:>13.5f} € | {cost_tier_hot:>14.2f} €")
    print(f"{'Cool (91-365d)':<15} | {vols['Cool']:>10.2f} GB | {rates['Cool']:>13.5f} € | {cost_tier_cool:>14.2f} €")
    print(f"{'Cold (1-3y)':<15} | {vols['Cold']:>10.2f} GB | {rates['Cold']:>13.5f} € | {cost_tier_cold:>14.2f} €")
    print(f"{'Archive (3-6+y)':<15} | {vols['Archive']:>10.2f} GB | {rates['Archive']:>13.5f} € | {cost_tier_archive:>14.2f} €")
    print("=" * 72)
    print(f"Steady-State Tiered Bill  : {cost_tiered_total:>10.2f} € / month")
    print(f"Traditional All-Hot Bill  : {cost_hot_baseline:>10.2f} € / month")
    print(f"Monthly Net Savings       : {monthly_savings:>10.2f} € / month  ({percentage_savings:.1f}% reduction)")
    print(f"Annual Recurring Savings  : {monthly_savings * 12:>10.2f} € / year")
    print(f"Estimated {years}-Year Savings   : {cumulative_savings:>10.2f} € net savings")
    print("=" * 72)

    # ASCII Comparison Bar
    hot_len = 50
    tiered_len = int((cost_tiered_total / cost_hot_baseline) * hot_len)
    print("\nVisual Cost Comparison (Monthly Bill):")
    print(f"All-Hot : [{'█' * hot_len}] {cost_hot_baseline:.2f} €")
    print(f"Tiered  : [{'█' * tiered_len}{' ' * (hot_len - tiered_len)}] {cost_tiered_total:.2f} €  (-{percentage_savings:.1f}%)")
    print("=" * 72)

def main():
    parser = argparse.ArgumentParser(
        description="Simulate TCO savings for Azure Blob Storage ERP compliance in Spain Central."
    )
    parser.add_argument(
        "--volume-gb",
        type=float,
        default=1000.0,
        help="Total document pool size in GB (default: 1000 GB = 1 TB)",
    )
    parser.add_argument(
        "--years",
        type=int,
        default=6,
        choices=[4, 6, 10],
        help="Retention duration: 6 (Código de Comercio), 4 (LGT General), 10 (LGT BINs) (default: 6)",
    )
    parser.add_argument(
        "--sku",
        type=str,
        default="ZRS",
        choices=["ZRS", "LRS"],
        help="Storage redundancy SKU: ZRS (default) or LRS",
    )

    args = parser.parse_args()
    print_tco_report(args.volume_gb, args.years, args.sku)

if __name__ == "__main__":
    main()
