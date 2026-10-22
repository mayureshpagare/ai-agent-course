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
    data_directory = DATA_DIRECTORY.resolve()

    file_path = (data_directory / file_name).resolve()

    if data_directory not in file_path.parents:
        raise ValueError("File access outside the data directory is not allowed.")

    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    if file_path.suffix.lower() != ".csv":
        raise ValueError("Only CSV files are allowed.")

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

def summarize_by_group(
    file_name: str,
    group_column: str,
    numeric_column: str
) -> list[dict]:
    """
    Group rows by one column and summarize a numeric column.

    Args:
        file_name: CSV file to analyze.
        group_column: Column used for grouping.
        numeric_column: Numeric column to summarize.

    Returns:
        Per-group row count, sum and average.
    """

    df = load_csv(file_name)

    if group_column not in df.columns:
        raise ValueError(
            f"Column does not exist: {group_column}"
        )

    if numeric_column not in df.columns:
        raise ValueError(
            f"Column does not exist: {numeric_column}"
        )

    df[numeric_column] = pd.to_numeric(
        df[numeric_column],
        errors="coerce"
    )

    grouped = (
        df.groupby(group_column)[numeric_column]
        .agg(
            count="count",
            total="sum",
            average="mean",
        )
        .reset_index()
    )

    return grouped.to_dict(
        orient="records"
    )

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

def summarize_by_group(
        file_name: str,
        group_column: str,
        numeric_column: str
) -> list[dict]:
    """
    Group rows by one column and summarize a numeric column.

    Args:
        file_name: CSV file to analyze.
        group_column: Column used for grouping.
        numeric_column: Numeric column to summarize.

    Returns:
        Per-group row count, sum and average.
    """

    df = load_csv(file_name)

    if group_column not in df.columns:
        raise ValueError(
            f"Column does not exist: {group_column}"
        )

    if numeric_column not in df.columns:
        raise ValueError(
            f"Column does not exist: {numeric_column}"
        )

    df[numeric_column] = pd.to_numeric(df[numeric_column], errors="coerce")

    grouped = (
        df.groupby(group_column)[numeric_column]
        .agg(count="count",total="sum",average="mean")
        .reset_index()
    )

    return grouped.to_dict(orient="records")

def search_text(file_name:str, query: str, limit:int = 20) -> list[dict]:
    """
    Search for a text query in all string columns of a CSV file.

    Args:
        file_name (str): The name of the CSV file to search.
        query (str): The text query to search for.
        limit (int): The maximum number of rows to return. Default is 20.

    Returns:
        Matching Rows.
    """
    df = load_csv(file_name)
    query = query.lower()

    mask = df.apply(
        lambda row: row.astype(str)
        .str.lower()
        .str.contains(
            query,regex = False
        )
        .any(),
        axis =1,
    )

    results = df[mask]

    return results.head(
        min(limit, 50)
    ).to_dict(orient="records")

def count_by_column_filtered(
    file_name: str,
    filter_column: str,
    filter_value: str,
    group_column: str,
) -> dict:
    """
    Filter rows first, then count values in another column.

    Args:
        file_name: CSV file to analyze.
        filter_column: Column used for filtering.
        filter_value: Required filter value.
        group_column: Column whose values should be counted.

    Returns:
        Counts grouped by the requested column after filtering.
    """

    df = load_csv(file_name)

    for column in [
        filter_column,
        group_column,
    ]:

        if column not in df.columns:

            raise ValueError(
                f"Column does not exist: {column}"
            )

    mask = (
        df[filter_column]
        .astype(str)
        .str.lower()
        == str(filter_value).lower()
    )

    filtered = df[mask]

    counts = (
        filtered[group_column]
        .fillna("NULL")
        .astype(str)
        .value_counts()
        .to_dict()
    )

    return counts

def list_csv_files() -> list[str]:
    """
    List all CSV files in the data directory.

    Returns:
        A list of CSV file names.
    """
    DATA_DIRECTORY.mkdir(exist_ok=True)  # Ensure the data directory exists

    return [path.name for path in DATA_DIRECTORY.glob("*.csv")]

def sort_rows(file_name: str, column: str, ascending: bool = True, limit: int = 20) -> list[dict]:
    """
    Sort rows in a CSV file based on a specific column.

    Args:
        file_name (str): The name of the CSV file to sort.
        column (str): The column name to sort by.
        ascending (bool): Whether to sort in ascending order. Default is True.
        limit (int): The maximum number of rows to return. Default is 20.

    Returns:
        Sorted Rows.
    """
    df = load_csv(file_name)
    df = df.sort_values(by=column, ascending=ascending)
    return df.head(min(limit, 50)).to_dict(orient="records")

def filter_rows_multi(
    file_name: str,
    filters: dict,
    limit: int = 20
) -> list[dict]:
    """
    Filter rows in a CSV file based on multiple column values.

    Args:
        file_name (str): The name of the CSV file to query.
        filters (dict): A dictionary where keys are column names and values are the values to filter by.
        limit (int): The maximum number of rows to return. Default is 20.

    Returns:
        Matching Rows.
    """
    df = load_csv(file_name)

    for column, value in filters.items():
        if column not in df.columns:
            raise ValueError(f"The column '{column}' does not exist in the CSV file.")

        df = df[df[column].astype(str).str.lower() == str(value).lower()]

    return df.head(min(limit, 50)).to_dict(orient="records")

def select_columns(
    file_name,
    columns,
    limit=20
) -> list[dict]:
    """
    Select specific columns from a CSV file.

    Args:
        file_name (str): The name of the CSV file to query.
        columns (list): A list of column names to select.
        limit (int): The maximum number of rows to return. Default is 20.
    
    Returns:
        Rows with only the selected columns.
    """
    df = load_csv(file_name)

    for column in columns:
        if column not in df.columns:
            raise ValueError(f"The column '{column}' does not exist in the CSV file")

        return df[columns].head(min(limit, 50)).to_dict(orient="records")