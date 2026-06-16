"""Data cleaning module"""
import pandas as pd
import numpy as np

def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """
    Basic cleaning: drop fully empty rows, deduplicate, mark negative amounts as NaN.
    """
    if df.empty:
        return df
    df = df.dropna(how='all')
    df = df.drop_duplicates(keep='first')
    if 'amount' in df.columns:
        df['amount'] = df['amount'].apply(
            lambda x: np.nan if pd.notna(x) and x < 0 else x
        )
    df = df.reset_index(drop=True)
    return df

class DataCleaner:
    """Utility class providing static batch cleaning methods."""
    @staticmethod
    def batch_clean_dataframe(df: pd.DataFrame, text_columns: list = None) -> pd.DataFrame:
        """
        Batch clean DataFrame, including basic cleaning and text column processing.
        :param df: Raw DataFrame
        :param text_columns: Text columns to clean (strip spaces, remove non-printable chars)
        :return: Cleaned DataFrame
        """
        df = clean_dataframe(df)
        if text_columns:
            for col in text_columns:
                if col in df.columns:
                    df[col] = df[col].astype(str).str.strip()
                    df[col] = df[col].apply(
                        lambda x: ''.join(char for char in x if char.isprintable()) if pd.notna(x) else x
                    )
        return df