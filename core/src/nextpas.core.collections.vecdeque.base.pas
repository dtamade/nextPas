unit nextpas.core.collections.vecdeque.base;

{$I nextpas.core.settings.inc}

interface

const
  VECDEQUE_DEFAULT_CAPACITY = 16;

type
  { 合并位置枚举 }
  TMergePosition = (mpFront, mpBack, mpReplace);

  { 排序算法类型枚举 }
  TSortAlgorithm = (
    saQuickSort,    // 快速排序 - 平均O(n log n)，最坏O(n²)，原地排序
    saMergeSort,    // 归并排序 - 稳定O(n log n)，需要额外空间
    saHeapSort,     // 堆排序 - 稳定O(n log n)，原地排序
    saIntroSort,    // 内省排序 - 混合算法，最优性能
    saInsertionSort // 插入排序 - 小数据集最优，O(n²)
  );

implementation

end.
