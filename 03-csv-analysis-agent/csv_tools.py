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