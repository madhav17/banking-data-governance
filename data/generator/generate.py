#!/usr/bin/env python3
"""Generate synthetic RAW banking CSV files from data/raw_data_spec_final.json."""

from __future__ import annotations

import csv
import json
import os
import random
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional, Tuple

SPEC_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "raw_data_spec_final.json",
)

INDIAN_STATES = [
    ("Maharashtra", "Mumbai", "400001"),
    ("Karnataka", "Bengaluru", "560001"),
    ("Tamil Nadu", "Chennai", "600001"),
    ("Delhi", "New Delhi", "110001"),
    ("Gujarat", "Ahmedabad", "380001"),
    ("West Bengal", "Kolkata", "700001"),
    ("Telangana", "Hyderabad", "500001"),
    ("Rajasthan", "Jaipur", "302001"),
    ("Kerala", "Kochi", "682001"),
    ("Punjab", "Chandigarh", "160001"),
]

FIRST_NAMES = [
    "Aarav", "Vivaan", "Aditi", "Ananya", "Rohan", "Priya", "Karan", "Neha",
    "Arjun", "Sneha", "Rahul", "Pooja", "Amit", "Kavya", "Sanjay", "Meera",
    "Vikram", "Divya", "Rajesh", "Lakshmi",
]

LAST_NAMES = [
    "Sharma", "Patel", "Reddy", "Iyer", "Gupta", "Singh", "Khan", "Nair",
    "Desai", "Mehta", "Joshi", "Rao", "Kapoor", "Malhotra", "Chopra", "Verma",
]

COMPANY_SUFFIXES = ["Pvt Ltd", "LLP", "Industries", "Solutions", "Enterprises", "Trading Co"]

TRANSACTION_CODE_MAP = {
    "CASH_DEPOSIT": "CD",
    "CASH_WITHDRAWAL": "CW",
    "TRANSFER": "TR",
    "CARD_PAYMENT": "CP",
    "ATM_WITHDRAWAL": "AW",
    "INTEREST_CREDIT": "IC",
    "FEE": "FE",
}

SINGLE_POSTING_TYPES = [
    "CASH_DEPOSIT",
    "CASH_WITHDRAWAL",
    "CARD_PAYMENT",
    "ATM_WITHDRAWAL",
    "INTEREST_CREDIT",
    "FEE",
]


def load_spec(path: str = SPEC_PATH) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def initialize_random(seed: int) -> random.Random:
    rng = random.Random(seed)
    return rng


def money(value: float) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def fmt_date(value: Optional[date]) -> str:
    if value is None:
        return ""
    return value.strftime("%Y-%m-%d")


def fmt_timestamp(value: datetime) -> str:
    return value.strftime("%Y-%m-%d %H:%M:%S")


def fmt_decimal(value: Decimal) -> str:
    return format(value, "f")


def fmt_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, date) and not isinstance(value, datetime):
        return fmt_date(value)
    if isinstance(value, datetime):
        return fmt_timestamp(value)
    if isinstance(value, Decimal):
        return fmt_decimal(value)
    return str(value)


def make_id(prefix: str, number: int, width: int) -> str:
    return "{}{}".format(prefix, str(number).zfill(width))


def weighted_choice(rng: random.Random, weights: Dict[str, float]) -> str:
    items = list(weights.keys())
    probs = [weights[item] for item in items]
    return rng.choices(items, weights=probs, k=1)[0]


def parse_date(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


def business_dates(start: date, end: date) -> List[date]:
    dates = []
    current = start
    while current <= end:
        dates.append(current)
        current += timedelta(days=1)
    return dates


def add_months(start: date, months: int) -> date:
    month_index = start.month - 1 + months
    year = start.year + month_index // 12
    month = month_index % 12 + 1
    day = min(start.day, [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,
                          31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1])
    return date(year, month, day)


class DataGenerator:
    def __init__(self, spec: Dict[str, Any]) -> None:
        self.spec = spec
        self.config = spec["generation_config"]
        self.rng = initialize_random(self.config["seed"])
        self.balance_start = parse_date(self.config["balance_date_range"]["start_date"])
        self.balance_end = parse_date(self.config["balance_date_range"]["end_date"])
        self.balance_dates = business_dates(self.balance_start, self.balance_end)

        self.branches: List[Dict[str, Any]] = []
        self.products: List[Dict[str, Any]] = []
        self.officers: List[Dict[str, Any]] = []
        self.customers: List[Dict[str, Any]] = []
        self.accounts: List[Dict[str, Any]] = []
        self.transactions: List[Dict[str, Any]] = []
        self.account_daily_balances: List[Dict[str, Any]] = []
        self.cards: List[Dict[str, Any]] = []
        self.loans: List[Dict[str, Any]] = []
        self.loan_collateral: List[Dict[str, Any]] = []
        self.gl_control_totals: List[Dict[str, Any]] = []

        self.officers_by_branch: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        self.products_by_type: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        self.deposit_products: List[Dict[str, Any]] = []
        self.loan_products: List[Dict[str, Any]] = []
        self.account_by_id: Dict[str, Dict[str, Any]] = {}
        self.customer_by_id: Dict[str, Dict[str, Any]] = {}
        self.card_numbers: List[str] = []
        self.metrics: Dict[str, Any] = {}

    def random_timestamp(self) -> datetime:
        base = datetime(2024, 1, 1)
        offset_days = self.rng.randint(0, 900)
        offset_seconds = self.rng.randint(0, 86399)
        return base + timedelta(days=offset_days, seconds=offset_seconds)

    def random_past_date(self, start_year: int = 2015, end_year: int = 2025) -> date:
        start = date(start_year, 1, 1)
        end = date(end_year, 12, 31)
        delta = (end - start).days
        return start + timedelta(days=self.rng.randint(0, delta))

    def random_date_in_balance_range(self) -> date:
        return self.rng.choice(self.balance_dates)

    def synthetic_tax_id(self) -> str:
        letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        part1 = "".join(self.rng.choice(letters) for _ in range(5))
        part2 = "".join(str(self.rng.randint(0, 9)) for _ in range(4))
        part3 = self.rng.choice(letters)
        return "{}{}{}".format(part1, part2, part3)

    def synthetic_phone(self) -> str:
        return "+91-{}-{}".format(
            self.rng.randint(70000, 99999),
            self.rng.randint(10000, 99999),
        )

    def synthetic_email(self, prefix: str) -> str:
        domains = ["example.com", "mailbank.in", "customer.co.in", "demo.org"]
        return "{}@{}".format(prefix.lower(), self.rng.choice(domains))

    def synthetic_account_number(self, seq: int) -> str:
        return "{}{}".format(self.rng.randint(100000, 999999), str(seq).zfill(8))

    def synthetic_loan_number(self, seq: int) -> str:
        return "LN{}{}".format(self.rng.randint(1000, 9999), str(seq).zfill(6))

    def synthetic_card_number(self) -> str:
        digits = [str(self.rng.randint(0, 9)) for _ in range(16)]
        formatted = "{}-{}-{}-{}".format(
            "".join(digits[0:4]),
            "".join(digits[4:8]),
            "".join(digits[8:12]),
            "".join(digits[12:16]),
        )
        return formatted

    def address_line(self) -> str:
        return "{} {} Road, Block {}".format(
            self.rng.randint(1, 250),
            self.rng.choice(["MG", "Park", "Station", "Lake", "Market"]),
            self.rng.choice(["A", "B", "C", "D"]),
        )

    def generate_branches(self) -> None:
        count = self.config["row_counts"]["branch"]
        branch_names = [
            "Central", "Metro", "City", "Plaza", "Square", "Heights",
            "Park", "Lake", "Market", "Station",
        ]
        for idx in range(1, count + 1):
            state, city, postal = self.rng.choice(INDIAN_STATES)
            row = {
                "branch_id": make_id("BR", idx, 3),
                "branch_code": "BC{}".format(str(idx).zfill(3)),
                "branch_name": "{} Branch".format(branch_names[idx - 1]),
                "region": self.rng.choice(["NORTH", "SOUTH", "EAST", "WEST"]),
                "city": city,
                "state": state,
                "postal_code": postal,
                "branch_status": self.rng.choice(["ACTIVE", "INACTIVE"]),
            }
            self.branches.append(row)

    def generate_products(self) -> None:
        count = self.config["row_counts"]["product"]
        product_types = (
            ["SAVINGS"] * 3
            + ["CURRENT"] * 3
            + ["FIXED_DEPOSIT"] * 3
            + ["PERSONAL_LOAN"] * 3
            + ["HOME_LOAN"] * 3
        )
        product_names = {
            "SAVINGS": ["Regular Savings", "Premium Savings", "Youth Savings"],
            "CURRENT": ["Business Current", "Retail Current", "Corporate Current"],
            "FIXED_DEPOSIT": ["Short Term FD", "Medium Term FD", "Long Term FD"],
            "PERSONAL_LOAN": ["Personal Flexi Loan", "Personal Term Loan", "Personal Quick Loan"],
            "HOME_LOAN": ["Home Purchase Loan", "Home Construction Loan", "Home Renovation Loan"],
        }
        counters = defaultdict(int)
        for idx in range(1, count + 1):
            product_type = product_types[idx - 1]
            counters[product_type] += 1
            name = product_names[product_type][counters[product_type] - 1]
            row = {
                "product_id": make_id("PR", idx, 3),
                "product_code": "PC{}{}".format(product_type[:2], str(idx).zfill(2)),
                "product_name": name,
                "product_type": product_type,
                "currency": "INR",
                "interest_rate": money(self.rng.uniform(2.5, 14.5)),
                "min_balance": money(self.rng.uniform(500, 10000)),
                "product_status": "ACTIVE",
            }
            self.products.append(row)
            self.products_by_type[product_type].append(row)
        self.deposit_products = (
            self.products_by_type["SAVINGS"]
            + self.products_by_type["CURRENT"]
            + self.products_by_type["FIXED_DEPOSIT"]
        )
        self.loan_products = (
            self.products_by_type["PERSONAL_LOAN"] + self.products_by_type["HOME_LOAN"]
        )

    def generate_officers(self) -> None:
        count = self.config["row_counts"]["officer"]
        roles = ["RELATIONSHIP_MANAGER", "BRANCH_MANAGER", "LOAN_OFFICER", "OPERATIONS"]
        for idx in range(1, count + 1):
            branch = self.rng.choice(self.branches)
            first = self.rng.choice(FIRST_NAMES)
            last = self.rng.choice(LAST_NAMES)
            prefix = "{}{}".format(first, last).lower()
            row = {
                "officer_id": make_id("OF", idx, 4),
                "officer_code": "OC{}".format(str(idx).zfill(4)),
                "officer_name": "{} {}".format(first, last),
                "branch_id": branch["branch_id"],
                "role": self.rng.choice(roles),
                "email": self.synthetic_email("officer{}".format(idx)),
                "status": self.rng.choice(["ACTIVE", "INACTIVE"]),
            }
            self.officers.append(row)
            self.officers_by_branch[branch["branch_id"]].append(row)

    def officer_for_branch(self, branch_id: str) -> Dict[str, Any]:
        officers = self.officers_by_branch[branch_id]
        if not officers:
            raise ValueError("No officers found for branch {}".format(branch_id))
        return self.rng.choice(officers)

    def generate_customers(self) -> None:
        count = self.config["row_counts"]["customer"]
        weights = self.spec["generation_rules"]["customer_type_distribution"]
        for idx in range(1, count + 1):
            branch = self.rng.choice(self.branches)
            officer = self.officer_for_branch(branch["branch_id"])
            customer_type = weighted_choice(self.rng, weights)
            tax_id = self.synthetic_tax_id()
            email = self.synthetic_email("customer{}".format(idx))
            phone = self.synthetic_phone()
            state, city, postal = self.rng.choice(INDIAN_STATES)
            row = {
                "customer_id": make_id("CU", idx, 5),
                "customer_type": customer_type,
                "first_name": None,
                "last_name": None,
                "business_name": None,
                "tax_id": tax_id,
                "date_of_birth": None,
                "email": email,
                "phone": phone,
                "address_line1": self.address_line(),
                "city": city,
                "state": state,
                "postal_code": postal,
                "country": "INDIA",
                "branch_id": branch["branch_id"],
                "officer_id": officer["officer_id"],
                "customer_status": self.rng.choice(["ACTIVE", "INACTIVE", "SUSPENDED"]),
                "created_date": self.random_past_date(2018, 2025),
                "updated_timestamp": self.random_timestamp(),
                "cust_ref": None,
                "notes": None,
            }
            if customer_type == "PERSON":
                row["first_name"] = self.rng.choice(FIRST_NAMES)
                row["last_name"] = self.rng.choice(LAST_NAMES)
                row["date_of_birth"] = self.random_past_date(1965, 2004)
            else:
                row["business_name"] = "{} {}".format(
                    self.rng.choice(["Global", "National", "Prime", "United", "Metro"]),
                    self.rng.choice(COMPANY_SUFFIXES),
                )
            if self.rng.random() < 0.75:
                row["cust_ref"] = tax_id
            if self.rng.random() < 0.75:
                row["notes"] = email
            self.customers.append(row)
            self.customer_by_id[row["customer_id"]] = row

    def generate_accounts(self) -> None:
        count = self.config["row_counts"]["account"]
        customer_ids = [row["customer_id"] for row in self.customers]
        assigned_customers = list(customer_ids)
        self.rng.shuffle(assigned_customers)
        extra_customers = [
            self.rng.choice(customer_ids) for _ in range(count - len(customer_ids))
        ]
        account_customers = assigned_customers + extra_customers

        for idx in range(1, count + 1):
            customer = self.customer_by_id[account_customers[idx - 1]]
            product = self.rng.choice(self.deposit_products)
            open_date = self.random_past_date(2018, 2025)
            if open_date > self.balance_start:
                open_date = self.balance_start - timedelta(days=self.rng.randint(30, 900))
            status = self.rng.choice(["ACTIVE", "CLOSED", "DORMANT"])
            close_date = None
            if status == "CLOSED":
                close_date = open_date + timedelta(days=self.rng.randint(180, 2000))
                if close_date > self.balance_end:
                    close_date = self.balance_end - timedelta(days=self.rng.randint(1, 10))
            row = {
                "account_id": make_id("AC", idx, 5),
                "account_number": self.synthetic_account_number(idx),
                "customer_id": customer["customer_id"],
                "product_id": product["product_id"],
                "branch_id": customer["branch_id"],
                "open_date": open_date,
                "close_date": close_date,
                "account_status": status,
                "currency": "INR",
                "current_balance": money(0),
                "account_type": product["product_type"],
                "_initial_opening_balance": money(self.rng.uniform(1000, 250000)),
            }
            self.accounts.append(row)
            self.account_by_id[row["account_id"]] = row

    def active_accounts(self) -> List[Dict[str, Any]]:
        return [row for row in self.accounts if row["account_status"] == "ACTIVE"]

    def debit_credit_for_type(self, transaction_type: str, is_transfer_debit: bool = False) -> str:
        if transaction_type == "TRANSFER":
            return "D" if is_transfer_debit else "C"
        if transaction_type in ("CASH_DEPOSIT", "INTEREST_CREDIT"):
            return "C"
        return "D"

    def channel_for_type(self, transaction_type: str) -> str:
        mapping = {
            "CASH_DEPOSIT": "BRANCH",
            "CASH_WITHDRAWAL": "BRANCH",
            "TRANSFER": self.rng.choice(["MOBILE", "INTERNET", "BRANCH"]),
            "CARD_PAYMENT": "CARD",
            "ATM_WITHDRAWAL": "ATM",
            "INTEREST_CREDIT": "INTERNET",
            "FEE": "INTERNET",
        }
        return mapping[transaction_type]

    def merchant_for_type(self, transaction_type: str) -> Optional[str]:
        if transaction_type != "CARD_PAYMENT":
            return None
        if self.rng.random() < 0.7:
            return self.rng.choice(
                ["FreshMart", "City Retail", "Online Bazaar", "Travel Hub", "Food Express"]
            )
        return None

    def build_transaction_row(
        self,
        seq: int,
        account: Dict[str, Any],
        transaction_type: str,
        amount: Decimal,
        txn_date: date,
        group_id: str,
        debit_credit: str,
    ) -> Dict[str, Any]:
        customer = self.customer_by_id[account["customer_id"]]
        card_number = None
        if self.rng.random() < 0.25:
            card_number = self.synthetic_card_number()
            self.card_numbers.append(card_number)
        reference = card_number if card_number and self.rng.random() < 0.5 else None
        memo = customer["phone"] if self.rng.random() < 0.25 else None
        return {
            "transaction_id": make_id("TX", seq, 7),
            "account_id": account["account_id"],
            "customer_id": account["customer_id"],
            "transaction_date": txn_date,
            "posting_date": txn_date,
            "transaction_type": transaction_type,
            "transaction_code": "{}{}".format(
                TRANSACTION_CODE_MAP[transaction_type],
                str(seq).zfill(4),
            ),
            "amount": amount,
            "currency": "INR",
            "debit_credit": debit_credit,
            "channel": self.channel_for_type(transaction_type),
            "merchant_name": self.merchant_for_type(transaction_type),
            "status": self.rng.choice(["POSTED", "REVERSED", "PENDING"]),
            "reference": reference,
            "memo": memo,
            "balance_after_transaction": money(0),
            "load_timestamp": self.random_timestamp(),
            "transaction_group_id": group_id,
        }

    def _debit_amount_for_balance(self, available: Decimal) -> Optional[Decimal]:
        if available <= 0:
            return None
        upper = min(Decimal("75000.00"), available)
        lower = min(Decimal("50.00"), upper)
        if upper < lower:
            return available
        return money(float(self.rng.uniform(float(lower), float(upper))))

    def _credit_amount(self) -> Decimal:
        return money(self.rng.uniform(50, 75000))

    def _transfer_amount_for_source(self, source_balance: Decimal) -> Decimal:
        if source_balance <= 0:
            raise ValueError("Transfer source balance must be positive.")
        upper = min(Decimal("75000.00"), source_balance)
        lower = min(Decimal("50.00"), upper)
        if upper < lower:
            return source_balance
        return money(float(self.rng.uniform(float(lower), float(upper))))

    def select_transfer_accounts(
        self,
        running: Dict[str, Decimal],
        active_accounts: List[Dict[str, Any]],
    ) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        eligible_sources = [
            account
            for account in active_accounts
            if running[account["account_id"]] > 0
        ]
        if not eligible_sources:
            raise ValueError("No active account has a positive running balance for transfer.")

        for _ in range(100):
            source_account = self.rng.choice(eligible_sources)
            destination_candidates = [
                account
                for account in active_accounts
                if account["account_id"] != source_account["account_id"]
            ]
            if not destination_candidates:
                continue
            destination_account = self.rng.choice(destination_candidates)
            if running[source_account["account_id"]] > 0:
                return source_account, destination_account

        source_account = max(
            eligible_sources,
            key=lambda account: running[account["account_id"]],
        )
        destination_account = next(
            account
            for account in active_accounts
            if account["account_id"] != source_account["account_id"]
        )
        return source_account, destination_account

    def _convert_skeleton_to_credit_deposit(self, skeleton: Dict[str, Any]) -> None:
        skeleton["transaction_type"] = "CASH_DEPOSIT"
        skeleton["debit_credit"] = "C"

    def _assign_transaction_amounts(self, skeletons: List[Dict[str, Any]]) -> None:
        running = {
            account_id: account["_initial_opening_balance"]
            for account_id, account in self.account_by_id.items()
        }
        transfer_lookup: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for skeleton in skeletons:
            if skeleton["transaction_type"] == "TRANSFER":
                transfer_lookup[skeleton["group_id"]].append(skeleton)

        skeletons.sort(
            key=lambda row: (
                row["transaction_date"],
                row["seq"],
            )
        )

        processed_transfer_groups = set()
        active_accounts = self.active_accounts()
        for skeleton in skeletons:
            account_id = skeleton["account"]["account_id"]

            if skeleton["transaction_type"] == "TRANSFER":
                group_id = skeleton["group_id"]
                if group_id in processed_transfer_groups:
                    continue
                pair = transfer_lookup[group_id]
                debit_skel = next(item for item in pair if item["debit_credit"] == "D")
                credit_skel = next(item for item in pair if item["debit_credit"] == "C")

                source_account, destination_account = self.select_transfer_accounts(
                    running,
                    active_accounts,
                )
                debit_skel["account"] = source_account
                credit_skel["account"] = destination_account

                source_balance = running[source_account["account_id"]]
                amount = self._transfer_amount_for_source(source_balance)
                debit_skel["amount"] = amount
                credit_skel["amount"] = amount
                running[source_account["account_id"]] -= amount
                running[destination_account["account_id"]] += amount

                processed_transfer_groups.add(group_id)
                continue

            if skeleton["debit_credit"] == "C":
                amount = self._credit_amount()
                skeleton["amount"] = amount
                running[account_id] += amount
            else:
                amount = self._debit_amount_for_balance(running[account_id])
                if amount is None:
                    self._convert_skeleton_to_credit_deposit(skeleton)
                    amount = self._credit_amount()
                    skeleton["amount"] = amount
                    running[account_id] += amount
                else:
                    skeleton["amount"] = amount
                    running[account_id] -= amount

        for skeleton in skeletons:
            row = self.build_transaction_row(
                skeleton["seq"],
                skeleton["account"],
                skeleton["transaction_type"],
                skeleton["amount"],
                skeleton["transaction_date"],
                skeleton["group_id"],
                skeleton["debit_credit"],
            )
            self.transactions.append(row)

    def generate_transactions(self) -> None:
        count = self.config["row_counts"]["transaction"]
        active = self.active_accounts()
        if len(active) < 2:
            raise ValueError("Need at least two active accounts for transfer generation.")

        transfer_groups = 10000
        single_rows = count - (transfer_groups * 2)
        if single_rows < 0:
            raise ValueError("Configured transaction count is too low for transfer pairs.")

        skeletons: List[Dict[str, Any]] = []
        seq = 1
        for group_idx in range(1, transfer_groups + 1):
            debit_account, credit_account = self.rng.sample(active, 2)
            txn_date = self.random_date_in_balance_range()
            group_id = make_id("GRP", group_idx, 5)
            skeletons.append(
                {
                    "seq": seq,
                    "account": debit_account,
                    "transaction_type": "TRANSFER",
                    "transaction_date": txn_date,
                    "group_id": group_id,
                    "debit_credit": "D",
                }
            )
            seq += 1
            skeletons.append(
                {
                    "seq": seq,
                    "account": credit_account,
                    "transaction_type": "TRANSFER",
                    "transaction_date": txn_date,
                    "group_id": group_id,
                    "debit_credit": "C",
                }
            )
            seq += 1

        for _ in range(single_rows):
            account = self.rng.choice(active)
            txn_type = self.rng.choice(SINGLE_POSTING_TYPES)
            txn_date = self.random_date_in_balance_range()
            skeletons.append(
                {
                    "seq": seq,
                    "account": account,
                    "transaction_type": txn_type,
                    "transaction_date": txn_date,
                    "group_id": make_id("GRP", transfer_groups + seq, 5),
                    "debit_credit": self.debit_credit_for_type(txn_type),
                }
            )
            seq += 1

        self._assign_transaction_amounts(skeletons)

    def compute_balance_after_transactions(self) -> None:
        txns_by_account: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for txn in self.transactions:
            txns_by_account[txn["account_id"]].append(txn)

        for account_id, txns in txns_by_account.items():
            txns.sort(
                key=lambda row: (
                    row["transaction_date"],
                    row["posting_date"],
                    row["transaction_id"],
                )
            )
            running = self.account_by_id[account_id]["_initial_opening_balance"]
            daily_totals: Dict[date, Dict[str, Decimal]] = defaultdict(
                lambda: {"credits": money(0), "debits": money(0)}
            )
            for txn in txns:
                txn_date = txn["transaction_date"]
                if txn["debit_credit"] == "C":
                    running += txn["amount"]
                    daily_totals[txn_date]["credits"] += txn["amount"]
                else:
                    running -= txn["amount"]
                    daily_totals[txn_date]["debits"] += txn["amount"]
                txn["balance_after_transaction"] = running
                txn["_daily_credit"] = daily_totals[txn_date]["credits"]
                txn["_daily_debit"] = daily_totals[txn_date]["debits"]

        for account in self.accounts:
            account["_daily_activity"] = defaultdict(
                lambda: {"credits": money(0), "debits": money(0)}
            )
        for txn in self.transactions:
            activity = self.account_by_id[txn["account_id"]]["_daily_activity"]
            txn_date = txn["transaction_date"]
            if txn["debit_credit"] == "C":
                activity[txn_date]["credits"] += txn["amount"]
            else:
                activity[txn_date]["debits"] += txn["amount"]

    def generate_account_daily_balances(self) -> None:
        expected = self.config["row_counts"]["account_daily_balance"]
        rows: List[Dict[str, Any]] = []
        for account in self.accounts:
            opening = account["_initial_opening_balance"]
            activity = account["_daily_activity"]
            for business_date in self.balance_dates:
                day = activity[business_date]
                closing = opening + day["credits"] - day["debits"]
                row = {
                    "account_id": account["account_id"],
                    "business_date": business_date,
                    "opening_balance": opening,
                    "closing_balance": closing,
                    "available_balance": closing,
                    "currency": "INR",
                    "source_system": "CORE_BANKING",
                    "load_timestamp": self.random_timestamp(),
                }
                rows.append(row)
                opening = closing
            account["current_balance"] = opening

        if len(rows) != expected:
            raise ValueError(
                "Expected {} daily balance rows, generated {}".format(expected, len(rows))
            )
        self.account_daily_balances = rows

    def generate_cards(self) -> None:
        count = self.config["row_counts"]["card"]
        selected_accounts = self.rng.sample(self.accounts, count)
        for idx in range(1, count + 1):
            account = selected_accounts[idx - 1]
            issue_date = self.random_past_date(2020, 2025)
            expiry_date = add_months(issue_date, self.rng.choice([36, 48, 60]))
            row = {
                "card_id": make_id("CA", idx, 5),
                "account_id": account["account_id"],
                "customer_id": account["customer_id"],
                "card_number": self.synthetic_card_number(),
                "card_type": self.rng.choice(["DEBIT", "CREDIT"]),
                "issue_date": issue_date,
                "expiry_date": expiry_date,
                "card_status": self.rng.choice(["ACTIVE", "BLOCKED", "EXPIRED"]),
            }
            self.cards.append(row)

    def generate_loans(self) -> None:
        count = self.config["row_counts"]["loan"]
        selected_customers = self.rng.sample(self.customers, count)
        tenure_values = self.spec["tables"]["loan"]["columns"]["tenure_months"]["allowed_values"]
        credit_weights = self.spec["tables"]["loan"]["columns"]["credit_grade"]["weights"]
        for idx in range(1, count + 1):
            customer = selected_customers[idx - 1]
            product = self.rng.choice(self.loan_products)
            officer = self.officer_for_branch(customer["branch_id"])
            loan_amount = money(self.rng.uniform(50000, 5000000))
            outstanding = money(float(loan_amount) * self.rng.uniform(0.1, 1.0))
            if outstanding > loan_amount:
                outstanding = loan_amount
            tenure = self.rng.choice(tenure_values)
            start_date = self.random_past_date(2018, 2024)
            row = {
                "loan_id": make_id("LN", idx, 5),
                "loan_number": self.synthetic_loan_number(idx),
                "customer_id": customer["customer_id"],
                "product_id": product["product_id"],
                "branch_id": customer["branch_id"],
                "officer_id": officer["officer_id"],
                "loan_type": product["product_type"],
                "loan_amount": loan_amount,
                "outstanding_amount": outstanding,
                "interest_rate": money(self.rng.uniform(7.0, 16.0)),
                "tenure_months": tenure,
                "start_date": start_date,
                "maturity_date": add_months(start_date, int(tenure)),
                "credit_grade": weighted_choice(self.rng, credit_weights),
                "loan_status": self.rng.choice(["ACTIVE", "CLOSED", "DEFAULTED"]),
            }
            self.loans.append(row)

    def generate_collateral(self) -> None:
        count = self.config["row_counts"]["loan_collateral"]
        loan_ids = [row["loan_id"] for row in self.loans]
        assigned_loans = list(loan_ids)
        if count > len(loan_ids):
            assigned_loans.extend(
                [self.rng.choice(loan_ids) for _ in range(count - len(loan_ids))]
            )
        else:
            assigned_loans = assigned_loans[:count]
        collateral_types = self.spec["tables"]["loan_collateral"]["columns"]["collateral_type"]["allowed_values"]
        descriptions = {
            "PROPERTY": "Residential property collateral",
            "VEHICLE": "Vehicle collateral",
            "DEPOSIT": "Fixed deposit lien",
            "SECURITIES": "Listed securities pledge",
        }
        for idx in range(1, count + 1):
            loan_id = assigned_loans[idx - 1]
            collateral_type = self.rng.choice(collateral_types)
            row = {
                "collateral_id": make_id("CO", idx, 5),
                "loan_id": loan_id,
                "collateral_type": collateral_type,
                "description": descriptions[collateral_type],
                "valuation_amount": money(self.rng.uniform(25000, 6000000)),
                "valuation_date": self.random_past_date(2019, 2025),
                "owner_name": "{} {}".format(
                    self.rng.choice(FIRST_NAMES),
                    self.rng.choice(LAST_NAMES),
                ),
                "collateral_status": self.rng.choice(["ACTIVE", "RELEASED"]),
            }
            self.loan_collateral.append(row)

    def generate_gl_control_totals(self) -> None:
        totals_by_date: Dict[date, Decimal] = defaultdict(lambda: money(0))
        for row in self.account_daily_balances:
            totals_by_date[row["business_date"]] += row["closing_balance"]

        txn_counts_by_date: Dict[date, int] = defaultdict(int)
        for txn in self.transactions:
            txn_counts_by_date[txn["posting_date"]] += 1

        for idx, business_date in enumerate(self.balance_dates, start=1):
            row = {
                "gl_control_id": make_id("GL", idx, 3),
                "business_date": business_date,
                "gl_account_code": "DEP-100",
                "product_type": "DEPOSIT",
                "currency": "INR",
                "control_total": totals_by_date[business_date],
                "transaction_count": txn_counts_by_date[business_date],
                "source_system": "GENERAL_LEDGER",
                "load_timestamp": self.random_timestamp(),
            }
            self.gl_control_totals.append(row)

    def validate_data(self) -> List[str]:
        errors: List[str] = []

        def add_error(table: str, rule: str, failing_count: int) -> None:
            errors.append(
                "table={} rule='{}' failing_record_count={}".format(
                    table, rule, failing_count
                )
            )

        table_data = {
            "branch": self.branches,
            "product": self.products,
            "officer": self.officers,
            "customer": self.customers,
            "account": self.accounts,
            "account_daily_balance": self.account_daily_balances,
            "transaction": self.transactions,
            "card": self.cards,
            "loan": self.loans,
            "loan_collateral": self.loan_collateral,
            "gl_control_total": self.gl_control_totals,
        }

        for table_name, rows in table_data.items():
            expected = self.config["row_counts"][table_name]
            if len(rows) != expected:
                add_error(
                    table_name,
                    "Row count must equal configured count ({})".format(expected),
                    abs(len(rows) - expected),
                )

        pk_checks = {
            "branch": ["branch_id"],
            "product": ["product_id"],
            "officer": ["officer_id"],
            "customer": ["customer_id"],
            "account": ["account_id"],
            "account_daily_balance": ["account_id", "business_date"],
            "transaction": ["transaction_id"],
            "card": ["card_id"],
            "loan": ["loan_id"],
            "loan_collateral": ["collateral_id"],
            "gl_control_total": ["gl_control_id"],
        }
        for table_name, keys in pk_checks.items():
            seen = set()
            duplicates = 0
            for row in table_data[table_name]:
                key = tuple(row[key] for key in keys)
                if key in seen:
                    duplicates += 1
                seen.add(key)
            if duplicates:
                add_error(table_name, "Primary keys are unique", duplicates)

        bk_checks = {
            "branch": ["branch_code"],
            "product": ["product_code"],
            "officer": ["officer_code"],
            "customer": ["customer_id"],
            "account": ["account_number"],
            "account_daily_balance": ["account_id", "business_date"],
            "transaction": ["transaction_id"],
            "card": ["card_number"],
            "loan": ["loan_number"],
            "loan_collateral": ["collateral_id"],
            "gl_control_total": ["business_date", "currency"],
        }
        for table_name, keys in bk_checks.items():
            seen = set()
            duplicates = 0
            for row in table_data[table_name]:
                key = tuple(row[key] for key in keys)
                if key in seen:
                    duplicates += 1
                seen.add(key)
            if duplicates:
                add_error(table_name, "Business keys are unique where defined", duplicates)

        branch_ids = {row["branch_id"] for row in self.branches}
        product_ids = {row["product_id"] for row in self.products}
        product_type_by_id = {row["product_id"]: row["product_type"] for row in self.products}
        officer_ids = {row["officer_id"] for row in self.officers}
        officer_branch = {row["officer_id"]: row["branch_id"] for row in self.officers}
        customer_ids = {row["customer_id"] for row in self.customers}
        account_ids = {row["account_id"] for row in self.accounts}
        loan_ids = {row["loan_id"] for row in self.loans}

        fk_failures = 0
        for row in self.officers:
            if row["branch_id"] not in branch_ids:
                fk_failures += 1
        if fk_failures:
            add_error("officer", "Foreign keys resolve", fk_failures)

        fk_failures = 0
        for row in self.customers:
            if row["branch_id"] not in branch_ids or row["officer_id"] not in officer_ids:
                fk_failures += 1
        if fk_failures:
            add_error("customer", "Foreign keys resolve", fk_failures)

        fk_failures = 0
        for row in self.accounts:
            if (
                row["customer_id"] not in customer_ids
                or row["product_id"] not in product_ids
                or row["branch_id"] not in branch_ids
            ):
                fk_failures += 1
        if fk_failures:
            add_error("account", "Foreign keys resolve", fk_failures)

        fk_failures = 0
        for row in self.transactions:
            if row["account_id"] not in account_ids or row["customer_id"] not in customer_ids:
                fk_failures += 1
        if fk_failures:
            add_error("transaction", "Foreign keys resolve", fk_failures)

        fk_failures = 0
        for row in self.account_daily_balances:
            if row["account_id"] not in account_ids:
                fk_failures += 1
        if fk_failures:
            add_error("account_daily_balance", "Foreign keys resolve", fk_failures)

        fk_failures = 0
        for row in self.cards:
            if row["account_id"] not in account_ids or row["customer_id"] not in customer_ids:
                fk_failures += 1
        if fk_failures:
            add_error("card", "Foreign keys resolve", fk_failures)

        fk_failures = 0
        for row in self.loans:
            if (
                row["customer_id"] not in customer_ids
                or row["product_id"] not in product_ids
                or row["branch_id"] not in branch_ids
                or row["officer_id"] not in officer_ids
            ):
                fk_failures += 1
        if fk_failures:
            add_error("loan", "Foreign keys resolve", fk_failures)

        fk_failures = 0
        for row in self.loan_collateral:
            if row["loan_id"] not in loan_ids:
                fk_failures += 1
        if fk_failures:
            add_error("loan_collateral", "Foreign keys resolve", fk_failures)

        accounts_by_customer = defaultdict(int)
        for row in self.accounts:
            accounts_by_customer[row["customer_id"]] += 1
        missing_accounts = sum(
            1 for customer in self.customers if accounts_by_customer[customer["customer_id"]] < 1
        )
        if missing_accounts:
            add_error("customer", "Every customer has at least one account", missing_accounts)

        officer_branch_failures = 0
        for row in self.customers:
            if officer_branch[row["officer_id"]] != row["branch_id"]:
                officer_branch_failures += 1
        if officer_branch_failures:
            add_error(
                "customer",
                "Customer officer belongs to the same branch as the customer",
                officer_branch_failures,
            )

        loan_officer_failures = 0
        for row in self.loans:
            if officer_branch[row["officer_id"]] != row["branch_id"]:
                loan_officer_failures += 1
        if loan_officer_failures:
            add_error(
                "loan",
                "Loan officer belongs to the same branch as the loan",
                loan_officer_failures,
            )

        loan_product_failures = 0
        for row in self.loans:
            if product_type_by_id[row["product_id"]] not in ("PERSONAL_LOAN", "HOME_LOAN"):
                loan_product_failures += 1
        if loan_product_failures:
            add_error("loan", "Loan product is a loan product", loan_product_failures)

        account_product_failures = 0
        for row in self.accounts:
            if product_type_by_id[row["product_id"]] not in (
                "SAVINGS",
                "CURRENT",
                "FIXED_DEPOSIT",
            ):
                account_product_failures += 1
        if account_product_failures:
            add_error("account", "Account product is a deposit product", account_product_failures)

        balance_key_counts = defaultdict(int)
        for row in self.account_daily_balances:
            balance_key_counts[(row["account_id"], row["business_date"])] += 1
        balance_grain_failures = sum(1 for count in balance_key_counts.values() if count != 1)
        if balance_grain_failures:
            add_error(
                "account_daily_balance",
                "Daily balance has one row per account per business date",
                balance_grain_failures,
            )

        formula_failures = 0
        opening_chain_failures = 0
        balances_by_account: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for row in self.account_daily_balances:
            balances_by_account[row["account_id"]].append(row)
        for account_id, rows in balances_by_account.items():
            rows.sort(key=lambda item: item["business_date"])
            account = self.account_by_id[account_id]
            for idx, row in enumerate(rows):
                activity = account["_daily_activity"][row["business_date"]]
                expected_close = row["opening_balance"] + activity["credits"] - activity["debits"]
                if row["closing_balance"] != expected_close:
                    formula_failures += 1
                if idx > 0 and row["opening_balance"] != rows[idx - 1]["closing_balance"]:
                    opening_chain_failures += 1
        if formula_failures:
            add_error(
                "account_daily_balance",
                "Closing balance follows the configured balance formula",
                formula_failures,
            )
        if opening_chain_failures:
            add_error(
                "account_daily_balance",
                "Next day opening balance equals previous day closing balance",
                opening_chain_failures,
            )

        customer_match_failures = 0
        for row in self.transactions:
            account = self.account_by_id[row["account_id"]]
            if row["customer_id"] != account["customer_id"]:
                customer_match_failures += 1
        if customer_match_failures:
            add_error(
                "transaction",
                "transaction.customer_id matches account.customer_id",
                customer_match_failures,
            )

        transfer_groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for row in self.transactions:
            if row["transaction_type"] == "TRANSFER":
                transfer_groups[row["transaction_group_id"]].append(row)

        groups_not_two_postings = sum(
            1 for rows in transfer_groups.values() if len(rows) != 2
        )
        if groups_not_two_postings:
            add_error(
                "transaction",
                "Every TRANSFER transaction_group_id has exactly 2 postings",
                groups_not_two_postings,
            )

        groups_not_one_debit = sum(
            1
            for rows in transfer_groups.values()
            if sum(1 for row in rows if row["debit_credit"] == "D") != 1
        )
        if groups_not_one_debit:
            add_error(
                "transaction",
                "Every TRANSFER group has exactly 1 debit posting",
                groups_not_one_debit,
            )

        groups_not_one_credit = sum(
            1
            for rows in transfer_groups.values()
            if sum(1 for row in rows if row["debit_credit"] == "C") != 1
        )
        if groups_not_one_credit:
            add_error(
                "transaction",
                "Every TRANSFER group has exactly 1 credit posting",
                groups_not_one_credit,
            )

        groups_with_unequal_amounts = sum(
            1
            for rows in transfer_groups.values()
            if len(rows) == 2
            and sum(row["amount"] for row in rows if row["debit_credit"] == "D")
            != sum(row["amount"] for row in rows if row["debit_credit"] == "C")
        )
        if groups_with_unequal_amounts:
            add_error(
                "transaction",
                "Debit amount equals credit amount for every TRANSFER group",
                groups_with_unequal_amounts,
            )

        transfer_group_ids = {make_id("GRP", group_idx, 5) for group_idx in range(1, 10001)}

        transfers_converted = sum(
            1
            for row in self.transactions
            if row["transaction_group_id"] in transfer_group_ids
            and row["transaction_type"] != "TRANSFER"
        )
        if transfers_converted:
            add_error(
                "transaction",
                "TRANSFER rows must remain transaction_type = TRANSFER",
                transfers_converted,
            )

        invalid_transfer_debits = 0
        running_for_transfers = {
            account_id: account["_initial_opening_balance"]
            for account_id, account in self.account_by_id.items()
        }
        ordered_for_transfers = sorted(
            self.transactions,
            key=lambda row: (
                row["transaction_date"],
                row["transaction_id"],
            ),
        )
        for txn in ordered_for_transfers:
            account_id = txn["account_id"]
            if txn["debit_credit"] == "D":
                if txn["transaction_type"] == "TRANSFER":
                    if txn["amount"] > running_for_transfers[account_id]:
                        invalid_transfer_debits += 1
                    elif running_for_transfers[account_id] - txn["amount"] < 0:
                        invalid_transfer_debits += 1
                running_for_transfers[account_id] -= txn["amount"]
            else:
                running_for_transfers[account_id] += txn["amount"]
        if invalid_transfer_debits:
            add_error(
                "transaction",
                "Source account has sufficient balance before transfer debit",
                invalid_transfer_debits,
            )

        transfer_failures = (
            groups_not_two_postings
            + groups_not_one_debit
            + groups_not_one_credit
            + groups_with_unequal_amounts
        )
        if transfer_failures:
            add_error(
                "transaction",
                "Internal transfers have balanced debit and credit postings",
                transfer_failures,
            )

        negative_opening = sum(
            1 for row in self.account_daily_balances if row["opening_balance"] < 0
        )
        if negative_opening:
            add_error("account_daily_balance", "No opening balance is negative", negative_opening)

        negative_closing = sum(
            1 for row in self.account_daily_balances if row["closing_balance"] < 0
        )
        if negative_closing:
            add_error("account_daily_balance", "No closing balance is negative", negative_closing)

        negative_available = sum(
            1 for row in self.account_daily_balances if row["available_balance"] < 0
        )
        if negative_available:
            add_error("account_daily_balance", "No available balance is negative", negative_available)

        invalid_debit_count = 0
        running_by_account = {
            account_id: account["_initial_opening_balance"]
            for account_id, account in self.account_by_id.items()
        }
        ordered_transactions = sorted(
            self.transactions,
            key=lambda row: (
                row["transaction_date"],
                row["posting_date"],
                row["transaction_id"],
            ),
        )
        for txn in ordered_transactions:
            account_id = txn["account_id"]
            if txn["debit_credit"] == "D":
                if txn["amount"] > running_by_account[account_id]:
                    invalid_debit_count += 1
                running_by_account[account_id] -= txn["amount"]
            else:
                running_by_account[account_id] += txn["amount"]
            if running_by_account[account_id] < 0:
                invalid_debit_count += 1
        if invalid_debit_count:
            add_error(
                "transaction",
                "No debit posting causes a negative running balance",
                invalid_debit_count,
            )

        nullable_columns = {
            "customer": ["first_name", "last_name", "business_name", "date_of_birth", "cust_ref", "notes"],
            "account": ["close_date"],
            "transaction": ["merchant_name", "reference", "memo"],
        }
        for table_name, nullable in nullable_columns.items():
            columns = self.spec["tables"][table_name]["columns"]
            failures = 0
            for row in table_data[table_name]:
                for column_name, column_spec in columns.items():
                    if column_name in nullable:
                        continue
                    if not column_spec.get("nullable", False) and row.get(column_name) in (None, ""):
                        failures += 1
            if failures:
                add_error(table_name, "Required fields are populated", failures)

        allowed_value_failures = 0
        for table_name, rows in table_data.items():
            columns = self.spec["tables"][table_name]["columns"]
            for row in rows:
                for column_name, column_spec in columns.items():
                    allowed = column_spec.get("allowed_values")
                    if allowed and row.get(column_name) not in allowed:
                        allowed_value_failures += 1
        if allowed_value_failures:
            add_error("multiple", "Allowed-value columns contain only configured values", allowed_value_failures)

        tolerance = Decimal(str(self.spec["generation_rules"]["gl_control_total"]["reconciliation_tolerance"]))
        gl_failures = 0
        totals_by_date: Dict[date, Decimal] = defaultdict(lambda: money(0))
        for row in self.account_daily_balances:
            totals_by_date[row["business_date"]] += row["closing_balance"]
        for row in self.gl_control_totals:
            expected = totals_by_date[row["business_date"]]
            delta = abs(row["control_total"] - expected)
            if delta > tolerance:
                gl_failures += 1
        if gl_failures:
            add_error(
                "gl_control_total",
                "GL control total equals aggregated daily deposit balances",
                gl_failures,
            )

        return errors

    def compute_metrics(self) -> Dict[str, Any]:
        min_opening = min(row["opening_balance"] for row in self.account_daily_balances)
        min_closing = min(row["closing_balance"] for row in self.account_daily_balances)
        min_available = min(row["available_balance"] for row in self.account_daily_balances)

        invalid_debit_count = 0
        running_by_account = {
            account_id: account["_initial_opening_balance"]
            for account_id, account in self.account_by_id.items()
        }
        ordered_transactions = sorted(
            self.transactions,
            key=lambda row: (
                row["transaction_date"],
                row["posting_date"],
                row["transaction_id"],
            ),
        )
        for txn in ordered_transactions:
            account_id = txn["account_id"]
            if txn["debit_credit"] == "D":
                if txn["amount"] > running_by_account[account_id]:
                    invalid_debit_count += 1
                running_by_account[account_id] -= txn["amount"]
            else:
                running_by_account[account_id] += txn["amount"]
            if running_by_account[account_id] < 0:
                invalid_debit_count += 1

        transfer_groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for row in self.transactions:
            if row["transaction_type"] == "TRANSFER":
                transfer_groups[row["transaction_group_id"]].append(row)

        transfer_groups_generated = len(transfer_groups)
        transfer_groups_with_two_postings = sum(
            1 for rows in transfer_groups.values() if len(rows) == 2
        )
        unbalanced_transfer_count = 0
        for rows in transfer_groups.values():
            if len(rows) != 2:
                unbalanced_transfer_count += 1
                continue
            debits = [row for row in rows if row["debit_credit"] == "D"]
            credits = [row for row in rows if row["debit_credit"] == "C"]
            if len(debits) != 1 or len(credits) != 1:
                unbalanced_transfer_count += 1
                continue
            if debits[0]["amount"] != credits[0]["amount"]:
                unbalanced_transfer_count += 1

        transfer_group_ids = {make_id("GRP", group_idx, 5) for group_idx in range(1, 10001)}
        transfers_converted_to_another_type = sum(
            1
            for row in self.transactions
            if row["transaction_group_id"] in transfer_group_ids
            and row["transaction_type"] != "TRANSFER"
        )

        invalid_transfer_debit_count = 0
        running_for_transfers = {
            account_id: account["_initial_opening_balance"]
            for account_id, account in self.account_by_id.items()
        }
        ordered_for_transfers = sorted(
            self.transactions,
            key=lambda row: (
                row["transaction_date"],
                row["transaction_id"],
            ),
        )
        for txn in ordered_for_transfers:
            account_id = txn["account_id"]
            if txn["debit_credit"] == "D":
                if txn["transaction_type"] == "TRANSFER":
                    if txn["amount"] > running_for_transfers[account_id]:
                        invalid_transfer_debit_count += 1
                    elif running_for_transfers[account_id] - txn["amount"] < 0:
                        invalid_transfer_debit_count += 1
                running_for_transfers[account_id] -= txn["amount"]
            else:
                running_for_transfers[account_id] += txn["amount"]

        negative_balance_count = sum(
            1
            for row in self.account_daily_balances
            if row["opening_balance"] < 0
            or row["closing_balance"] < 0
            or row["available_balance"] < 0
        )

        totals_by_date: Dict[date, Decimal] = defaultdict(lambda: money(0))
        for row in self.account_daily_balances:
            totals_by_date[row["business_date"]] += row["closing_balance"]

        max_gl_difference = money(0)
        for row in self.gl_control_totals:
            expected = totals_by_date[row["business_date"]]
            delta = abs(row["control_total"] - expected)
            if delta > max_gl_difference:
                max_gl_difference = delta

        return {
            "min_opening_balance": min_opening,
            "min_closing_balance": min_closing,
            "min_available_balance": min_available,
            "invalid_debit_count": invalid_debit_count,
            "unbalanced_transfer_count": unbalanced_transfer_count,
            "max_gl_reconciliation_difference": max_gl_difference,
            "transfer_groups_generated": transfer_groups_generated,
            "transfer_groups_with_two_postings": transfer_groups_with_two_postings,
            "transfers_converted_to_another_type": transfers_converted_to_another_type,
            "invalid_transfer_debit_count": invalid_transfer_debit_count,
            "negative_balance_count": negative_balance_count,
        }

    def strip_internal_fields(self) -> None:
        for account in self.accounts:
            account.pop("_initial_opening_balance", None)
            account.pop("_daily_activity", None)

    def write_csv_files(self, output_dir: str) -> None:
        os.makedirs(output_dir, exist_ok=True)
        datasets = {
            "branch.csv": (self.branches, self.spec["tables"]["branch"]["columns"]),
            "product.csv": (self.products, self.spec["tables"]["product"]["columns"]),
            "officer.csv": (self.officers, self.spec["tables"]["officer"]["columns"]),
            "customer.csv": (self.customers, self.spec["tables"]["customer"]["columns"]),
            "account.csv": (self.accounts, self.spec["tables"]["account"]["columns"]),
            "account_daily_balance.csv": (
                self.account_daily_balances,
                self.spec["tables"]["account_daily_balance"]["columns"],
            ),
            "transaction.csv": (self.transactions, self.spec["tables"]["transaction"]["columns"]),
            "card.csv": (self.cards, self.spec["tables"]["card"]["columns"]),
            "loan.csv": (self.loans, self.spec["tables"]["loan"]["columns"]),
            "loan_collateral.csv": (
                self.loan_collateral,
                self.spec["tables"]["loan_collateral"]["columns"],
            ),
            "gl_control_total.csv": (
                self.gl_control_totals,
                self.spec["tables"]["gl_control_total"]["columns"],
            ),
        }
        for filename, (rows, columns) in datasets.items():
            path = os.path.join(output_dir, filename)
            fieldnames = list(columns.keys())
            with open(path, "w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
                writer.writeheader()
                for row in rows:
                    writer.writerow({key: fmt_value(row.get(key)) for key in fieldnames})

    def run(self) -> Dict[str, int]:
        self.generate_branches()
        self.generate_products()
        self.generate_officers()
        self.generate_customers()
        self.generate_accounts()
        self.generate_transactions()
        self.compute_balance_after_transactions()
        self.generate_account_daily_balances()
        self.generate_cards()
        self.generate_loans()
        self.generate_collateral()
        self.generate_gl_control_totals()

        self.metrics = self.compute_metrics()
        errors = self.validate_data()
        if errors:
            message = "Validation failed:\n" + "\n".join(errors)
            raise SystemExit(message)

        self.strip_internal_fields()
        output_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "generated",
            "raw",
        )
        configured_output = self.config.get("output_directory", "data/generated/raw")
        if configured_output.startswith("data/"):
            output_dir = os.path.join(
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                *configured_output.split("/")[1:],
            )
        self.write_csv_files(output_dir)

        return {
            "branch": len(self.branches),
            "product": len(self.products),
            "officer": len(self.officers),
            "customer": len(self.customers),
            "account": len(self.accounts),
            "account_daily_balance": len(self.account_daily_balances),
            "transaction": len(self.transactions),
            "card": len(self.cards),
            "loan": len(self.loans),
            "loan_collateral": len(self.loan_collateral),
            "gl_control_total": len(self.gl_control_totals),
            "metrics": self.metrics,
        }


def main() -> None:
    spec = load_spec()
    generator = DataGenerator(spec)
    result = generator.run()
    metrics = result.pop("metrics")
    print("Generation completed successfully.")
    for table_name, count in result.items():
        print("  {}: {}".format(table_name, count))
    print("Transfer validation:")
    print("  Transfer groups generated: {}".format(metrics["transfer_groups_generated"]))
    print(
        "  Transfer groups with 2 postings: {}".format(
            metrics["transfer_groups_with_two_postings"]
        )
    )
    print("  Unbalanced transfer groups: {}".format(metrics["unbalanced_transfer_count"]))
    print(
        "  Transfers converted to another type: {}".format(
            metrics["transfers_converted_to_another_type"]
        )
    )
    print("  Invalid transfer debits: {}".format(metrics["invalid_transfer_debit_count"]))
    print("  Negative balances: {}".format(metrics["negative_balance_count"]))
    print(
        "  GL reconciliation difference: {}".format(
            fmt_decimal(metrics["max_gl_reconciliation_difference"])
        )
    )


if __name__ == "__main__":
    main()
