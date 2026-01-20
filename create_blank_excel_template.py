import pandas as pd
import openpyxl

def create_blank_template(source_excel, output_excel):
    """從現有 Excel 檔案創建空白模板"""
    
    # 讀取原始 Excel 檔案
    xlsx = pd.ExcelFile(source_excel)
    
    print(f'📖 讀取原始檔案: {source_excel}')
    print(f'   找到 {len(xlsx.sheet_names)} 個 sheets: {xlsx.sheet_names}\n')
    
    # 創建新的 Excel writer
    with pd.ExcelWriter(output_excel, engine='openpyxl') as writer:
        for sheet_name in xlsx.sheet_names:
            # 讀取原始 sheet（只讀取第一行作為欄位名稱）
            df = pd.read_excel(xlsx, sheet_name=sheet_name, nrows=0)
            
            # 創建只有欄位名稱的空 DataFrame
            blank_df = pd.DataFrame(columns=df.columns)
            
            # 寫入空白 sheet
            blank_df.to_excel(writer, sheet_name=sheet_name, index=False)
            
            print(f'✅ 創建空白 sheet: {sheet_name}')
            print(f'   欄位數: {len(df.columns)}')
            if len(df.columns) > 0:
                print(f'   欄位: {", ".join(df.columns[:8])}{"..." if len(df.columns) > 8 else ""}')
            print()
    
    print(f'✅ 空白模板已創建: {output_excel}')
    print(f'\n💡 使用說明:')
    print(f'   1. 打開 {output_excel}')
    print(f'   2. 在對應的 sheet 中填入資料')
    print(f'   3. 只填寫需要更新的欄位即可（其他欄位可留空）')
    print(f'   4. 執行上傳腳本: python3 upload_v3_excel.py --key tools/keys/service-account.json --excel {output_excel}')

if __name__ == '__main__':
    source_excel = 'learning_bubble_upload_ready_v2_all_fixed.xlsx'
    output_excel = 'learning_bubble_template_blank.xlsx'
    
    try:
        create_blank_template(source_excel, output_excel)
    except Exception as e:
        print(f'❌ 錯誤: {e}')
        import traceback
        traceback.print_exc()
