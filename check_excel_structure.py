import pandas as pd
import sys

def check_excel_structure(excel_file):
    """檢查 Excel 檔案結構是否符合上傳腳本要求"""
    
    print(f'📋 檢查 Excel 檔案: {excel_file}\n')
    print('=' * 60)
    
    try:
        xlsx = pd.ExcelFile(excel_file)
        sheet_names = xlsx.sheet_names
        
        print(f'\n✅ 找到 {len(sheet_names)} 個工作表: {sheet_names}\n')
        
        # 定義每個工作表需要的必要欄位
        required_fields = {
            'UI_SEGMENTS': ['segmentId', 'title', 'order', 'mode', 'published'],
            'TOPICS': ['topicId', 'title', 'published', 'order'],
            'PRODUCTS': ['productId', 'topicId', 'level'],  # title, titleLower, order 可自動生成
            'FEATURED_LISTS': ['listId', 'title', 'type', 'ids'],
            'CONTENT_ITEMS': ['itemId', 'productId'],
        }
        
        all_valid = True
        
        for sheet_name in required_fields.keys():
            print(f'\n📊 檢查工作表: {sheet_name}')
            print('-' * 60)
            
            if sheet_name not in sheet_names:
                print(f'❌ 錯誤: 缺少必要工作表 "{sheet_name}"')
                all_valid = False
                continue
            
            try:
                df = pd.read_excel(excel_file, sheet_name=sheet_name)
                print(f'✅ 工作表存在')
                print(f'   資料筆數: {len(df)}')
                print(f'   欄位數: {len(df.columns)}')
                
                # 檢查必要欄位
                missing_fields = []
                for field in required_fields[sheet_name]:
                    if field not in df.columns:
                        missing_fields.append(field)
                
                if missing_fields:
                    print(f'❌ 缺少必要欄位: {", ".join(missing_fields)}')
                    all_valid = False
                else:
                    print(f'✅ 所有必要欄位都存在')
                
                # 顯示所有欄位
                print(f'\n   所有欄位 ({len(df.columns)}):')
                for i, col in enumerate(df.columns, 1):
                    required_mark = ' ⭐' if col in required_fields[sheet_name] else ''
                    print(f'   {i:2d}. {col}{required_mark}')
                
                # 檢查資料完整性（只檢查必要欄位是否有空值）
                if len(df) > 0:
                    print(f'\n   資料完整性檢查:')
                    for field in required_fields[sheet_name]:
                        if field in df.columns:
                            null_count = df[field].isna().sum()
                            if null_count > 0:
                                print(f'   ⚠️  {field}: {null_count} 筆資料為空')
                            else:
                                print(f'   ✅ {field}: 無空值')
                
            except Exception as e:
                print(f'❌ 讀取工作表時發生錯誤: {e}')
                all_valid = False
        
        # 檢查是否有額外的工作表
        extra_sheets = [s for s in sheet_names if s not in required_fields.keys()]
        if extra_sheets:
            print(f'\n📌 額外的工作表（不會被上傳）: {extra_sheets}')
        
        print('\n' + '=' * 60)
        if all_valid:
            print('\n✅ 檢查完成：檔案結構符合上傳要求！')
            print('\n💡 可以執行上傳指令:')
            print(f'   python3 upload_v3_excel.py --key ./tools/keys/service-account.json --excel {excel_file}')
        else:
            print('\n❌ 檢查完成：發現問題，請修正後再上傳')
        
        return all_valid
        
    except FileNotFoundError:
        print(f'❌ 錯誤: 找不到檔案 "{excel_file}"')
        return False
    except Exception as e:
        print(f'❌ 錯誤: {e}')
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    excel_file = 'learning_bubble_template_1.xlsx'
    if len(sys.argv) > 1:
        excel_file = sys.argv[1]
    
    check_excel_structure(excel_file)
