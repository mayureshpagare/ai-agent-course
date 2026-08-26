"""Arithmetic tools exposed to the calculator agent.

Each function performs exactly one operation. The docstrings are deliberately
explicit because agent frameworks use them to decide which tool to call and
how to populate its arguments.
"""


def add(a: float, b: float) -> float:
    """Add two numbers and return their sum.

    Use this tool for requests containing "add", "plus", "sum", or "total".

    Args:
        a: The first number to add.
        b: The second number to add.
    """
    return a + b


def subtract(a: float, b: float) -> float:
    """Subtract the second number from the first and return the difference.

    Use this tool for requests containing "subtract", "minus", "difference",
    "decrease by", or "how much remains". Argument order matters: this
    computes ``a - b``.

    Args:
        a: The number to subtract from (the minuend).
        b: The number to subtract (the subtrahend).
    """
    return a - b


def multiply(a: float, b: float) -> float:
    """Multiply two numbers and return their product.

    Use this tool for requests containing "multiply", "times", "product", or
    repeated equal groups.

    Args:
        a: The first factor.
        b: The second factor.
    """
    return a * b


def divide(a: float, b: float) -> float:
    """Divide the first number by the second and return the quotient.

    Use this tool for requests containing "divide", "divided by", "quotient",
    "ratio", or equal sharing. Argument order matters: this computes ``a / b``.

    Args:
        a: The dividend (the number being divided).
        b: The divisor (the number to divide by); it must not be zero.

    Raises:
        ValueError: If ``b`` is zero.
    """
    if b == 0:
        raise ValueError("Cannot divide by zero.")
    return a / b


def power(a: float, b: float) -> float:
    """Raise a base to an exponent and return the result.

    Use this tool for requests containing "power", "raised to", "exponent",
    "squared", or "cubed". Argument order matters: this computes ``a ** b``.

    Args:
        a: The base number.
        b: The exponent.
    """
    return a**b


def percentage(value: float, percent: float) -> float:
    """Calculate a percentage of a value.

    Use this tool only for requests such as "what is X percent of Y?" For
    example, ``percentage(value=200, percent=10)`` returns ``20``. Do not use
    it to calculate percentage increase, decrease, or percentage difference.

    Args:
        value: The whole amount that the percentage is taken from.
        percent: The percentage rate, expressed as a normal number such as
            ``10`` for 10%, not ``0.10``.
    """
    return (value / 100) * percent

def discounted_price(original_price: float, discount_percent: float) -> float:
    """Calculate the discounted price after applying a percentage discount.

    Use this tool for requests such as "what is the price after a X% discount on Y?" 
    For example, ``discounted_price(original_price=100, discount_percent=20)`` returns ``80.0``.

    Args:
        original_price: The original price before discount.
        discount_percent: The discount percentage to apply, expressed as a normal number such as
            ``20`` for 20%, not ``0.20``.
    """
    if original_price < 0:
        raise ValueError("Original price cannot be negative.")
    if discount_percent < 0 or discount_percent > 100:
        raise ValueError("Discount percent must be between 0 and 100.")
    return original_price * (1 - discount_percent / 100)

def calculate_percentage_difference(value1: float, value2: float) -> float:
    """Calculate the percentage difference between two values.

    Use this tool for requests such as "what is the percentage difference between X and Y?" 
    For example, ``calculate_percentage_difference(value1=100, value2=150)`` returns ``40.0``.

    Args:
        value1: The first value.
        value2: The second value.
    """
    if (value1 + value2) == 0:
        raise ValueError("The sum of the two values cannot be zero for percentage difference calculation.")
    return abs(value1 - value2) / ((value1 + value2) / 2) * 100

def calculate_percentage_of_total(part: float, total: float) -> float:
    """Calculate what percentage a part is of a total.

    Use this tool for requests such as "what percentage is X of Y?" 
    For example, ``calculate_percentage_of_total(part=50, total=200)`` returns ``25.0``.

    Args:
        part: The part value.
        total: The total value; it must not be zero.
    """
    if total == 0:
        raise ValueError("Total value cannot be zero for percentage of total calculation.")
    return (part / total) * 100

def calculate_percentage_change(original: float, new: float) -> float:  
    """Calculate the percentage change from an original value to a new value.

    Use this tool for requests such as "what is the percentage change from X to Y?" 
    For example, ``calculate_percentage_change(original=100, new=150)`` returns ``50.0``.

    Args:
        original: The original value.
        new: The new value.
    """
    if original == 0:
        raise ValueError("Original value cannot be zero for percentage change calculation.")
    return ((new - original) / original) * 100

def calculate_percentage_increase_or_decrease(original: float, new: float) -> float:
    """Calculate the percentage increase or decrease from an original value to a new value.

    Use this tool for requests such as "what is the percentage increase or decrease from X to Y?" 
    For example, ``calculate_percentage_increase_or_decrease(original=100, new=150)`` returns ``50.0``, 
    and ``calculate_percentage_increase_or_decrease(original=150, new=100)`` returns ``-33.33``.

    Args:
        original: The original value.
        new: The new value.
    """
    if original == 0:
        raise ValueError("Original value cannot be zero for percentage increase or decrease calculation.")
    return ((new - original) / original) * 100

def gst(amount: float, gst_rate: float) -> float:
    """Calculate the GST (Goods and Services Tax) for a given amount.

    Use this tool for requests such as "what is the GST on X at Y%?" 
    For example, ``gst(amount=100, gst_rate=10)`` returns ``10.0``.

    Args:
        amount: The original amount before GST.
        gst_rate: The GST rate as a percentage (e.g., 10 for 10%).
    """
    if amount < 0:
        raise ValueError("Amount cannot be negative.")
    if gst_rate < 0:
        raise ValueError("GST rate cannot be negative.")
    return (amount * gst_rate) / 100