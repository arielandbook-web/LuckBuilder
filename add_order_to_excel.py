import pandas as pd
import openpyxl

def add_order_column(excel_path):
    """在 PRODUCTS sheet 中添加 order 欄位"""
    
    # 讀取 Excel 檔案
    xlsx = pd.ExcelFile(excel_path)
    
    # 讀取 PRODUCTS sheet
    df = pd.read_excel(xlsx, sheet_name='PRODUCTS')
    
    # 檢查是否已經有 order 欄位
    if 'order' in df.columns:
        print('⚠️  order 欄位已存在，將更新現有值')
    else:
        print('✅ 添加 order 欄位')
    
    # 按 topicId 分組，然後在每個組內按 level 排序，最後分配 order 值
    # 如果沒有 topicId，就按 productId 排序
    df_sorted = df.copy()
    
    # 確保 topicId 和 level 欄位存在
    if 'topicId' in df.columns and 'level' in df.columns:
        # 按 topicId 和 level 排序
        df_sorted = df_sorted.sort_values(by=['topicId', 'level'])
        # 按 topicId 分組，在每個組內分配 order（從 1 開始）
        df_sorted['order'] = df_sorted.groupby('topicId').cumcount() + 1
    else:
        # 如果沒有 topicId 或 level，就按 productId 排序並分配順序
        df_sorted = df_sorted.sort_values(by='productId')
        df_sorted['order'] = range(1, len(df_sorted) + 1)
    
    # 將 order 移到合適的位置（放在 published 之後）
    cols = list(df_sorted.columns)
    if 'order' in cols:
        cols.remove('order')
    # 找到 published 的位置
    if 'published' in cols:
        published_idx = cols.index('published')
        cols.insert(published_idx + 1, 'order')
    else:
        cols.append('order')
    
    df_sorted = df_sorted[cols]
    
    # 讀取所有 sheets
    with pd.ExcelWriter(excel_path, engine='openpyxl', mode='a', if_sheet_exists='replace') as writer:
        # 寫回所有 sheets
        for sheet_name in xlsx.sheet_names:
            if sheet_name == 'PRODUCTS':
                df_sorted.to_excel(writer, sheet_name=sheet_name, index=False)
                print(f'✅ 已更新 {sheet_name} sheet，添加 order 欄位')
            else:
                # 保留其他 sheets 不變
                df_other = pd.read_excel(xlsx, sheet_name=sheet_name)
                df_other.to_excel(writer, sheet_name=sheet_name, index=False)
    
    # 顯示結果
    print(f'\n📊 更新後的 PRODUCTS sheet:')
    print(f'   總行數: {len(df_sorted)}')
    print(f'   order 欄位範圍: {df_sorted["order"].min()} - {df_sorted["order"].max()}')
    print(f'\n前 5 行資料:')
    print(df_sorted[['productId', 'topicId', 'level', 'order']].head())
    
    return df_sorted

if __name__ == '__main__':
    excel_path = 'learning_bubble_upload_ready_v2_all_fixed.xlsx'
    try:
        df = add_order_column(excel_path)
        print(f'\n✅ 完成！已成功添加 order 欄位到 {excel_path}')
    except Exception as e:
        print(f'❌ 錯誤: {e}')
        import traceback
        traceback.print_exc()
