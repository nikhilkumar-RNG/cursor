#!/usr/bin/env python3
"""
Cost Comparison Calculator: Loki + Tempo vs ELK
Compares storage and infrastructure costs for different scales
"""

import json
from dataclasses import dataclass
from typing import Dict

@dataclass
class StorageCosts:
    """Storage cost per GB per month"""
    s3_standard: float = 0.023
    s3_ia: float = 0.0125  # Infrequent Access
    s3_glacier: float = 0.004
    ebs_gp3: float = 0.08
    ebs_io2: float = 0.125

@dataclass
class InstanceCosts:
    """EC2/Compute costs per hour"""
    t3_medium: float = 0.0416  # 2 vCPU, 4GB RAM
    t3_large: float = 0.0832   # 2 vCPU, 8GB RAM
    t3_xlarge: float = 0.1664  # 4 vCPU, 16GB RAM
    m5_xlarge: float = 0.192   # 4 vCPU, 16GB RAM
    m5_2xlarge: float = 0.384  # 8 vCPU, 32GB RAM
    m5_4xlarge: float = 0.768  # 16 vCPU, 64GB RAM

class LokiCostCalculator:
    def __init__(self, storage_costs: StorageCosts):
        self.storage_costs = storage_costs
        self.compression_ratio = 8  # Typical 8:1 compression
        
    def calculate(self, daily_logs_gb: float, retention_days: int) -> Dict:
        """Calculate Loki + Tempo costs"""
        
        # Storage calculation
        compressed_daily = daily_logs_gb / self.compression_ratio
        total_storage_gb = compressed_daily * retention_days
        storage_cost = total_storage_gb * self.storage_costs.s3_standard
        
        # Instance costs for Loki
        if daily_logs_gb < 50:
            loki_instance_hours = 730 * 0.0832  # t3.large
            loki_instance_type = "t3.large"
        elif daily_logs_gb < 200:
            loki_instance_hours = 730 * 0.1664  # t3.xlarge
            loki_instance_type = "t3.xlarge"
        else:
            loki_instance_hours = 730 * 0.384   # m5.2xlarge
            loki_instance_type = "m5.2xlarge"
        
        # Promtail/Fluent Bit (minimal overhead on existing nodes)
        collector_cost = 0  # Runs as DaemonSet on existing nodes
        
        # Tempo costs
        traces_gb = daily_logs_gb * 0.1  # Assume traces are ~10% of log volume
        tempo_storage_gb = (traces_gb * retention_days) / 5  # Better compression for traces
        tempo_storage_cost = tempo_storage_gb * self.storage_costs.s3_standard
        tempo_instance_cost = 730 * 0.0832  # t3.large for Tempo
        
        # Grafana (shared, minimal cost)
        grafana_cost = 730 * 0.0416  # t3.medium
        
        total_cost = storage_cost + loki_instance_hours + tempo_storage_cost + tempo_instance_cost + grafana_cost
        
        return {
            "solution": "Loki + Tempo",
            "daily_logs_gb": daily_logs_gb,
            "retention_days": retention_days,
            "loki_storage_gb": total_storage_gb,
            "loki_storage_cost": storage_cost,
            "loki_instance_type": loki_instance_type,
            "loki_instance_cost": loki_instance_hours,
            "tempo_storage_gb": tempo_storage_gb,
            "tempo_storage_cost": tempo_storage_cost,
            "tempo_instance_cost": tempo_instance_cost,
            "grafana_cost": grafana_cost,
            "collector_cost": collector_cost,
            "total_monthly_cost": total_cost,
            "storage_efficiency": f"{self.compression_ratio}:1"
        }

class ElasticsearchCostCalculator:
    def __init__(self, storage_costs: StorageCosts):
        self.storage_costs = storage_costs
        self.overhead_multiplier = 1.3  # ES uses ~30% more for indices, mappings
        self.replication_factor = 1  # Single replica
        
    def calculate(self, daily_logs_gb: float, retention_days: int) -> Dict:
        """Calculate ELK stack costs"""
        
        # Storage calculation (with overhead and replication)
        daily_with_overhead = daily_logs_gb * self.overhead_multiplier
        total_storage_gb = daily_with_overhead * retention_days * (1 + self.replication_factor)
        storage_cost = total_storage_gb * self.storage_costs.ebs_gp3
        
        # Instance costs - need more powerful instances
        if daily_logs_gb < 50:
            # Small cluster: 3 nodes (m5.xlarge)
            num_nodes = 3
            instance_cost_per_hour = 0.192
            instance_type = "3x m5.xlarge"
        elif daily_logs_gb < 200:
            # Medium cluster: 3 nodes (m5.2xlarge)
            num_nodes = 3
            instance_cost_per_hour = 0.384
            instance_type = "3x m5.2xlarge"
        else:
            # Large cluster: 5 nodes (m5.2xlarge)
            num_nodes = 5
            instance_cost_per_hour = 0.384
            instance_type = "5x m5.2xlarge"
        
        es_instance_cost = num_nodes * instance_cost_per_hour * 730
        
        # Kibana
        kibana_cost = 730 * 0.1664  # t3.xlarge
        
        # Logstash/Beats
        logstash_cost = 730 * 0.1664  # t3.xlarge
        
        # Jaeger for tracing (separate from ELK)
        jaeger_storage_gb = (daily_logs_gb * 0.1 * retention_days)
        jaeger_storage_cost = jaeger_storage_gb * self.storage_costs.ebs_gp3
        jaeger_instance_cost = 730 * 0.192  # m5.xlarge
        
        total_cost = (storage_cost + es_instance_cost + kibana_cost + 
                     logstash_cost + jaeger_storage_cost + jaeger_instance_cost)
        
        return {
            "solution": "Elasticsearch + Kibana + Jaeger",
            "daily_logs_gb": daily_logs_gb,
            "retention_days": retention_days,
            "es_storage_gb": total_storage_gb,
            "es_storage_cost": storage_cost,
            "es_cluster": instance_type,
            "es_instance_cost": es_instance_cost,
            "kibana_cost": kibana_cost,
            "logstash_cost": logstash_cost,
            "jaeger_storage_gb": jaeger_storage_gb,
            "jaeger_storage_cost": jaeger_storage_cost,
            "jaeger_instance_cost": jaeger_instance_cost,
            "total_monthly_cost": total_cost,
            "storage_efficiency": "1:1 (with overhead)"
        }

def generate_comparison_report():
    """Generate comprehensive cost comparison report"""
    
    storage_costs = StorageCosts()
    loki_calc = LokiCostCalculator(storage_costs)
    elk_calc = ElasticsearchCostCalculator(storage_costs)
    
    # Test scenarios
    scenarios = [
        {"name": "Small (10 GB/day)", "daily_gb": 10, "retention": 30},
        {"name": "Medium (100 GB/day)", "daily_gb": 100, "retention": 30},
        {"name": "Large (1 TB/day)", "daily_gb": 1000, "retention": 30},
        {"name": "Medium with 90d retention", "daily_gb": 100, "retention": 90},
    ]
    
    print("=" * 80)
    print("COST COMPARISON: Loki + Tempo vs Elasticsearch + Kibana + Jaeger")
    print("=" * 80)
    print()
    
    for scenario in scenarios:
        print(f"\n{'=' * 80}")
        print(f"Scenario: {scenario['name']}")
        print(f"Daily logs: {scenario['daily_gb']} GB, Retention: {scenario['retention']} days")
        print('=' * 80)
        
        loki_result = loki_calc.calculate(scenario['daily_gb'], scenario['retention'])
        elk_result = elk_calc.calculate(scenario['daily_gb'], scenario['retention'])
        
        print(f"\nLoki + Tempo Solution:")
        print(f"  Storage: {loki_result['loki_storage_gb']:.1f} GB (compressed {loki_result['storage_efficiency']})")
        print(f"  Storage cost: ${loki_result['loki_storage_cost']:.2f}/mo")
        print(f"  Loki instance: {loki_result['loki_instance_type']} (${loki_result['loki_instance_cost']:.2f}/mo)")
        print(f"  Tempo cost: ${loki_result['tempo_storage_cost'] + loki_result['tempo_instance_cost']:.2f}/mo")
        print(f"  Grafana cost: ${loki_result['grafana_cost']:.2f}/mo")
        print(f"  TOTAL: ${loki_result['total_monthly_cost']:.2f}/mo")
        
        print(f"\nElasticsearch + Kibana + Jaeger Solution:")
        print(f"  Storage: {elk_result['es_storage_gb']:.1f} GB (with overhead & replication)")
        print(f"  Storage cost: ${elk_result['es_storage_cost']:.2f}/mo")
        print(f"  ES cluster: {elk_result['es_cluster']} (${elk_result['es_instance_cost']:.2f}/mo)")
        print(f"  Kibana: ${elk_result['kibana_cost']:.2f}/mo")
        print(f"  Logstash: ${elk_result['logstash_cost']:.2f}/mo")
        print(f"  Jaeger: ${elk_result['jaeger_storage_cost'] + elk_result['jaeger_instance_cost']:.2f}/mo")
        print(f"  TOTAL: ${elk_result['total_monthly_cost']:.2f}/mo")
        
        savings = elk_result['total_monthly_cost'] - loki_result['total_monthly_cost']
        savings_pct = (savings / elk_result['total_monthly_cost']) * 100
        
        print(f"\n{'=' * 40}")
        print(f"💰 SAVINGS with Loki + Tempo: ${savings:.2f}/mo ({savings_pct:.1f}%)")
        print(f"💰 Annual savings: ${savings * 12:.2f}/year")
        print('=' * 40)
    
    # Generate JSON output
    all_results = []
    for scenario in scenarios:
        loki_result = loki_calc.calculate(scenario['daily_gb'], scenario['retention'])
        elk_result = elk_calc.calculate(scenario['daily_gb'], scenario['retention'])
        
        all_results.append({
            "scenario": scenario['name'],
            "loki_tempo": loki_result,
            "elk_jaeger": elk_result,
            "savings_monthly": elk_result['total_monthly_cost'] - loki_result['total_monthly_cost'],
            "savings_percentage": ((elk_result['total_monthly_cost'] - loki_result['total_monthly_cost']) 
                                  / elk_result['total_monthly_cost'] * 100)
        })
    
    with open('cost_comparison_results.json', 'w') as f:
        json.dump(all_results, f, indent=2)
    
    print("\n\n" + "=" * 80)
    print("Detailed results saved to: cost_comparison_results.json")
    print("=" * 80)

if __name__ == "__main__":
    generate_comparison_report()
