#!/usr/bin/env python3
"""
Test Data Generator for Talend Benchmark
Generates CSV files with realistic sample data for ETL benchmarking
"""

import csv
import random
import argparse
import sys
from datetime import datetime, timedelta
from pathlib import Path


class DataGenerator:
    """Generate realistic test data for benchmarking"""

    def __init__(self, seed=42):
        """Initialize generator with seed for reproducibility"""
        random.seed(seed)
        self.first_names = [
            "James", "Mary", "John", "Patricia", "Robert", "Jennifer",
            "Michael", "Linda", "William", "Elizabeth", "David", "Barbara",
            "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah"
        ]
        self.last_names = [
            "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia",
            "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez",
            "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas"
        ]
        self.products = [
            "Laptop", "Desktop", "Monitor", "Keyboard", "Mouse",
            "Headphones", "Webcam", "Printer", "Scanner", "Tablet"
        ]
        self.statuses = ["Completed", "Pending", "Cancelled", "Processing"]
        self.countries = [
            "USA", "Canada", "UK", "Germany", "France",
            "Japan", "Australia", "Brazil", "India", "China"
        ]

    def generate_name(self):
        """Generate a random full name"""
        return f"{random.choice(self.first_names)} {random.choice(self.last_names)}"

    def generate_email(self, name):
        """Generate email from name"""
        clean_name = name.lower().replace(" ", ".")
        domains = ["example.com", "test.com", "demo.org", "sample.net"]
        return f"{clean_name}@{random.choice(domains)}"

    def generate_phone(self):
        """Generate a random phone number"""
        area = random.randint(200, 999)
        prefix = random.randint(200, 999)
        line = random.randint(1000, 9999)
        return f"+1-{area}-{prefix}-{line}"

    def generate_amount(self, min_val=10, max_val=10000):
        """Generate random monetary amount"""
        return round(random.uniform(min_val, max_val), 2)

    def generate_date(self, start_date=None, days_back=365):
        """Generate random date within range"""
        if start_date is None:
            start_date = datetime.now()
        days_ago = random.randint(0, days_back)
        date = start_date - timedelta(days=days_ago)
        return date.strftime("%Y-%m-%d")

    def generate_transaction_row(self, row_id):
        """Generate a single transaction record"""
        name = self.generate_name()
        return {
            "id": row_id,
            "customer_name": name,
            "email": self.generate_email(name),
            "phone": self.generate_phone(),
            "product": random.choice(self.products),
            "quantity": random.randint(1, 10),
            "unit_price": self.generate_amount(50, 2000),
            "amount": self.generate_amount(100, 20000),
            "status": random.choice(self.statuses),
            "country": random.choice(self.countries),
            "order_date": self.generate_date(),
            "notes": f"Order #{row_id} - {random.choice(['Express', 'Standard', 'Economy'])} shipping"
        }


def estimate_file_size(num_records):
    """Estimate CSV file size in MB"""
    # Average row size ~200 bytes (rough estimate)
    avg_row_size = 200
    size_bytes = num_records * avg_row_size
    size_mb = size_bytes / (1024 * 1024)
    return round(size_mb, 2)


def calculate_records_for_size(target_size_mb):
    """Calculate number of records needed for target file size"""
    avg_row_size = 200  # bytes
    target_bytes = target_size_mb * 1024 * 1024
    return int(target_bytes / avg_row_size)


def generate_csv(filename, num_records, verbose=True):
    """Generate CSV file with specified number of records"""
    generator = DataGenerator()

    if verbose:
        print(f"Generating {num_records:,} records...")
        print(f"Estimated file size: {estimate_file_size(num_records)} MB")

    # Ensure output directory exists
    output_path = Path(filename)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Write CSV
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        fieldnames = [
            'id', 'customer_name', 'email', 'phone', 'product',
            'quantity', 'unit_price', 'amount', 'status',
            'country', 'order_date', 'notes'
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)

        # Write header
        writer.writeheader()

        # Write data
        for i in range(1, num_records + 1):
            row = generator.generate_transaction_row(i)
            writer.writerow(row)

            # Progress indicator
            if verbose and i % 100000 == 0:
                print(f"  Progress: {i:,} / {num_records:,} ({i*100//num_records}%)")

    # Verify file size
    actual_size = output_path.stat().st_size / (1024 * 1024)
    if verbose:
        print(f"✓ File created: {filename}")
        print(f"✓ Actual file size: {actual_size:.2f} MB")
        print(f"✓ Total records: {num_records:,}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate test CSV data for Talend benchmarks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate 1 million records
  python generate-test-data.py --records 1000000 --output data.csv

  # Generate ~1GB file
  python generate-test-data.py --size 1000 --output 1gb-sample.csv

  # Generate multiple test files
  python generate-test-data.py --size 100 --output small.csv
  python generate-test-data.py --size 1000 --output medium.csv
  python generate-test-data.py --size 10000 --output large.csv
        """
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '--records', '-r',
        type=int,
        help='Number of records to generate'
    )
    group.add_argument(
        '--size', '-s',
        type=float,
        help='Target file size in MB'
    )

    parser.add_argument(
        '--output', '-o',
        type=str,
        default='test-data.csv',
        help='Output CSV file path (default: test-data.csv)'
    )

    parser.add_argument(
        '--quiet', '-q',
        action='store_true',
        help='Suppress progress output'
    )

    args = parser.parse_args()

    # Calculate number of records
    if args.size:
        num_records = calculate_records_for_size(args.size)
        if not args.quiet:
            print(f"Target size: {args.size} MB → {num_records:,} records")
    else:
        num_records = args.records

    # Generate CSV
    try:
        generate_csv(args.output, num_records, verbose=not args.quiet)
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
