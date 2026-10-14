from pathlib import Path
import pandas as pd

DATA_DIRECTORY = Path("data")

def load_csv(file_name: str) -> pd.DataFrame:
    """
    Load a CSV file into a pandas DataFrame.

    Args:
        file_name (str): The name of the CSV file to load.

    Returns:
        pd.DataFrame: The loaded DataFrame.
    """
    file_path = DATA_DIRECTORY / file_name
    if not file_path.exists():
        raise FileNotFoundError(f"The file {file_name} does not exist in the data directory.")

    if file_path.suffix.lower() != ".csv":
        raise ValueError("Only CSV files are supported. Please provide a valid CSV file.")

    return pd.read_csv(file_path)

def inspect_csv(file_name:str) -> dict:
    """
    Inspect a CSV file and return basic information about it.

    Args:
        file_name (str): The name of the CSV file to inspect.

    Returns:
        Number of rows, columns, column names and data types.
    """
    df = load_csv(file_name)

    return {
        "rows":len(df),
        "columns":len(df.columns),
        "column_names":df.columns.tolist(),
        "data_types":{column : str(dtype) for column, dtype in df.dtypes.items()}
    }

def preview_csv(file_name:str, limit:int = 5) -> list[dict]:
    """
    Preview the first few rows of a CSV file.

    Args:
        file_name (str): The name of the CSV file to preview.
        limit (int): The number of rows to preview. Default is 5.

    Returns:
        A list of dictionaries representing the first few rows of the DataFrame.
    """
    if limit < 1:
        raise ValueError("Limit must be greater than 0")
    
    if limit > 20:
        limit = 20  # Cap the limit to 20 rows
    
    df = load_csv(file_name)

    return df.head(limit).to_dict(orient="records")

def filter_rows(file_name:str, column:str, value:str, limit:int = 20) -> list[dict]:
    """
    Filter rows in a CSV file based on a specific column value.

    Args:
        file_name (str): The name of the CSV file to query.
        column (str): The column name to filter by.
        value (str): The value that should match.
        limit (int): The maximum number of rows to return. Default is 20.

    Returns:
        Matching Rows.
    """
    df = load_csv(file_name)

    if column not in df.columns:
        raise ValueError(f"The column '{column}' does not exist in the CSV file.")

    if limit < 1:
        raise ValueError("Limit must be greater than 0")

    limit = min(limit, 50)  # Cap the limit to 50 rows

    series = df[column].astype(str)  # Convert the column to string for comparison

    filtered_df = df[series.str.lower() == str(value).lower()]

    return filtered_df.head(limit).to_dict(orient="records")

def count_rows(file_name:str) -> int:
    """
    Count the number of rows in a CSV file.

    Args:
        file_name (str): The name of the CSV file to query.

    Returns:
        The count of rows.
    """
    df = load_csv(file_name)

    return len(df)

def count_by_column(
    file_name: str,
    column: str
) -> dict:
    """
    Count how many rows exist for each value in a column.

    Args:
        file_name: CSV file to analyze.
        column: Column whose values should be counted.

    Returns:
        Mapping of column values to their counts.
    """

    df = load_csv(file_name)

    if column not in df.columns:
        raise ValueError(
            f"Column does not exist: {column}"
        )

    counts = (
        df[column]
        .fillna("NULL")
        .astype(str)
        .value_counts()
        .to_dict()
    )

    return counts

def summarize_numeric_column(
    file_name: str,
    column: str
) -> dict:
    """
    Calculate common statistics for a numeric column.

    Args:
        file_name: CSV file to analyze.
        column: Numeric column to summarize.

    Returns:
        Count, sum, average, minimum and maximum.
    """

    df = load_csv(file_name)

    if column not in df.columns:
        raise ValueError(
            f"Column does not exist: {column}"
        )

    numeric = pd.to_numeric(
        df[column],
        errors="coerce"
    ).dropna()

    if numeric.empty:
        raise ValueError(
            f"Column is not numeric: {column}"
        )

    return {
        "count": int(numeric.count()),
        "sum": float(numeric.sum()),
        "average": float(numeric.mean()),
        "minimum": float(numeric.min()),
        "maximum": float(numeric.max()),
    }