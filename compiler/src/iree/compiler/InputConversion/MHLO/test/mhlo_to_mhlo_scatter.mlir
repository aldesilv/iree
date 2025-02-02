// RUN: iree-opt --split-input-file --verify-diagnostics --iree-mhlo-to-mhlo-preprocessing %s | FileCheck %s

func.func @scatter_implicit_batch(%arg0: tensor<5x5xi32>, %arg1: tensor<2xi32>, %arg2: tensor<i32>) -> tensor<5x5xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    "mhlo.return"(%arg4) : (tensor<i32>) -> ()
  }) {indices_are_sorted = true, scatter_dimension_numbers = #mhlo.scatter<inserted_window_dims = [0, 1], scatter_dims_to_operand_dims = [0, 1]>, unique_indices = true} : (tensor<5x5xi32>, tensor<2xi32>, tensor<i32>) -> tensor<5x5xi32>
  return %0 : tensor<5x5xi32>
}

// CHECK-LABEL: func.func @scatter_implicit_batch
// CHECK-DAG: %[[RE_I:.+]] = tensor.expand_shape %{{.*}} {{\[\[}}0, 1]] : tensor<2xi32> into tensor<1x2xi32>
// CHECK-DAG: %[[RE_U:.+]] = tensor.expand_shape %{{.*}} [] : tensor<i32> into tensor<1xi32>
// CHECK:     %[[SCATTER:.+]] = "mhlo.scatter"(%{{.*}}, %[[RE_I]], %[[RE_U]])
// CHECK:       mhlo.return %{{.*}}

// -----

func.func @scatter_implicit_indices(%arg0: tensor<17x11xf32>,
  %arg1: tensor<7xi32>, %arg2: tensor<7x11xf32>) -> tensor<17x11xf32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<f32>, %arg4: tensor<f32>):
    %1 = mhlo.add %arg3, %arg4 : tensor<f32>
    "mhlo.return"(%1) : (tensor<f32>) -> ()
  }) {indices_are_sorted = false,
      scatter_dimension_numbers = #mhlo.scatter<
      update_window_dims = [1],
      inserted_window_dims = [0],
      scatter_dims_to_operand_dims = [0],
      index_vector_dim = 1>, 
      unique_indices = false
      } : (tensor<17x11xf32>, tensor<7xi32>, tensor<7x11xf32>) -> tensor<17x11xf32>
  return %0 : tensor<17x11xf32>
}

// CHECK-LABEL: func.func @scatter_implicit_indices
// CHECK: %[[EXPAND:.+]] = tensor.expand_shape %arg1 {{\[\[}}0, 1]] : tensor<7xi32> into tensor<7x1xi32>
// CHECK: %[[SCATTER:.+]] = "mhlo.scatter"(%arg0, %[[EXPAND]], %arg2) ({
// CHECK-NEXT: ^bb0(%[[A0:.+]]: tensor<f32>, %[[A1:.+]]: tensor<f32>):
// CHECK-NEXT:   %[[ADD:.+]] = mhlo.add %[[A0]], %[[A1]] : tensor<f32>
// CHECK-NEXT:   mhlo.return %[[ADD]]
// CHECK-NEXT: })
// CHECK-SAME: indices_are_sorted = false,
// CHECK-SAME: scatter_dimension_numbers = #mhlo.scatter<
// CHECK-SAME:   update_window_dims = [1],
// CHECK-SAME:   inserted_window_dims = [0],
// CHECK-SAME:   scatter_dims_to_operand_dims = [0],
// CHECK-SAME:   index_vector_dim = 1>,
// CHECK-SAME:   unique_indices = false

// -----

func.func @scatter_collapse_batch(%arg0: tensor<1x24x512xi32>,
    %arg1: tensor<2x3x2xi32>, %arg2: tensor<2x3x512xi32>) -> tensor<1x24x512xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ( {
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    "mhlo.return"(%arg4) : (tensor<i32>) -> ()
  }) {indices_are_sorted = false,
      scatter_dimension_numbers = #mhlo.scatter<
        update_window_dims = [2],
        inserted_window_dims = [0, 1],
        scatter_dims_to_operand_dims = [0, 1],
        index_vector_dim = 2,
      >,
      unique_indices = true
  } : (tensor<1x24x512xi32>, tensor<2x3x2xi32>, tensor<2x3x512xi32>) -> tensor<1x24x512xi32>
  return %0 : tensor<1x24x512xi32>
}

// CHECK-LABEL: func.func @scatter_collapse_batch
// CHECK: %[[COLLAPSE0:.+]] = tensor.collapse_shape %arg1 {{\[\[}}0, 1], [2]] : tensor<2x3x2xi32> into tensor<6x2xi32>
// CHECK: %[[COLLAPSE1:.+]] = tensor.collapse_shape %arg2 {{\[\[}}0, 1], [2]] : tensor<2x3x512xi32> into tensor<6x512xi32>
// CHECK: %[[SCATTER:.+]] = "mhlo.scatter"(%arg0, %[[COLLAPSE0]], %[[COLLAPSE1]])
// CHECK: ^bb0(%[[ARG0:.+]]: tensor<i32>, %[[ARG1:.+]]: tensor<i32>):
// CHECK:   mhlo.return %[[ARG1]]
// CHECK: }) {
// CHECK: indices_are_sorted = false,
// CHECK-SAME: scatter_dimension_numbers = #mhlo.scatter<
// CHECK-SAME: update_window_dims = [1]
// CHECK-SAME: inserted_window_dims = [0, 1]
// CHECK-SAME: scatter_dims_to_operand_dims = [0, 1]
// CHECK-SAME: index_vector_dim = 1>
// CHECK-SAME: unique_indices = true
// CHECK: return %[[SCATTER]]

// -----

func.func @scatter_materialize_index_update(%arg0: tensor<5x1x1xi32>, %arg1: tensor<1x2xi32>, %arg2: tensor<1x4xi32>) -> tensor<5x1x1xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    "mhlo.return"(%arg4) : (tensor<i32>) -> ()
  }) {
    indices_are_sorted = true,
    scatter_dimension_numbers = #mhlo.scatter<update_window_dims = [1],
                                              inserted_window_dims = [1, 2],
                                              scatter_dims_to_operand_dims = [0, 1],
                                              index_vector_dim = 1>,
    unique_indices = true} : (tensor<5x1x1xi32>, tensor<1x2xi32>, tensor<1x4xi32>) -> tensor<5x1x1xi32>
  return %0 : tensor<5x1x1xi32>
}

// CHECK-LABEL: @scatter_materialize_index_update
// CHECK: %[[EXPAND:.+]] = tensor.expand_shape %arg2 {{\[\[}}0], [1, 2, 3]] : tensor<1x4xi32> into tensor<1x4x1x1xi32>
// CHECK: %[[SCATTER:.+]] = "mhlo.scatter"(%arg0, %arg1, %[[EXPAND]])
// CHECK:                   indices_are_sorted = true, scatter_dimension_numbers = #mhlo.scatter<
// CHECK-SAME:                update_window_dims = [1, 2, 3]
// CHECK-SAME:                scatter_dims_to_operand_dims = [0, 1]
// CHECK-SAME:                index_vector_dim = 1>, unique_indices = true

// -----

func.func @scatter_materialize_one_dim(%arg0: tensor<5x1x1xi32>, %arg1: tensor<1x2xi32>, %arg2: tensor<1xi32>) -> tensor<5x1x1xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    "mhlo.return"(%arg4) : (tensor<i32>) -> ()
  }) {
    indices_are_sorted = true,
    scatter_dimension_numbers = #mhlo.scatter<update_window_dims = [],
                                              inserted_window_dims = [0, 1, 2],
                                              scatter_dims_to_operand_dims = [0, 1],
                                              index_vector_dim = 1>,
    unique_indices = true} : (tensor<5x1x1xi32>, tensor<1x2xi32>, tensor<1xi32>) -> tensor<5x1x1xi32>
  return %0 : tensor<5x1x1xi32>
}

// CHECK-LABEL: @scatter_materialize_one_dim
// CHECK: %[[EXPAND:.+]] = tensor.expand_shape %arg2 {{\[\[}}0, 1]] : tensor<1xi32> into tensor<1x1xi32>
// CHECK: %[[SCATTER:.+]] = "mhlo.scatter"(%arg0, %arg1, %[[EXPAND]])
// CHECK:                   indices_are_sorted = true, scatter_dimension_numbers = #mhlo.scatter<
// CHECK-SAME:                 update_window_dims = [1]
// CHECK-SAME:                 inserted_window_dims = [0, 1]
// CHECK-SAME:                 scatter_dims_to_operand_dims = [0, 1]
// CHECK-SAME:                 index_vector_dim = 1>, unique_indices = true

// -----

func.func @scatter_materialize_two_dims(%arg0: tensor<5x1x1xi32>, %arg1: tensor<1x1xi32>, %arg2: tensor<1xi32>) -> tensor<5x1x1xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    "mhlo.return"(%arg4) : (tensor<i32>) -> ()
  }) {
    indices_are_sorted = true,
    scatter_dimension_numbers = #mhlo.scatter<update_window_dims = [],
                                              inserted_window_dims = [0, 1, 2],
                                              scatter_dims_to_operand_dims = [0],
                                              index_vector_dim = 1>,
    unique_indices = true} : (tensor<5x1x1xi32>, tensor<1x1xi32>, tensor<1xi32>) -> tensor<5x1x1xi32>
  return %0 : tensor<5x1x1xi32>
}

// CHECK-LABEL: @scatter_materialize_two_dims
// CHECK: %[[EXPAND:.+]] = tensor.expand_shape %arg2 {{\[\[}}0, 1, 2]] : tensor<1xi32> into tensor<1x1x1xi32>
// CHECK: %[[SCATTER:.+]] = "mhlo.scatter"(%arg0, %arg1, %[[EXPAND]])
// CHECK:                   indices_are_sorted = true, scatter_dimension_numbers = #mhlo.scatter<
// CHECK-SAME:                 update_window_dims = [1, 2]
// CHECK-SAME:                 inserted_window_dims = [0]
// CHECK-SAME:                 scatter_dims_to_operand_dims = [0]
// CHECK-SAME:                 index_vector_dim = 1>, unique_indices = true

// -----

func.func @scatter_materialize_comprehensive(%arg0: tensor<5x4x1xi32>, %arg1: tensor<1x1xi32>, %arg2: tensor<1x4xi32>) -> tensor<5x4x1xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    "mhlo.return"(%arg4) : (tensor<i32>) -> ()
  }) {
    indices_are_sorted = true,
    scatter_dimension_numbers = #mhlo.scatter<update_window_dims = [1],
                                              inserted_window_dims = [0, 2],
                                              scatter_dims_to_operand_dims = [0],
                                              index_vector_dim = 1>,
    unique_indices = true} : (tensor<5x4x1xi32>, tensor<1x1xi32>, tensor<1x4xi32>) -> tensor<5x4x1xi32>
  return %0 : tensor<5x4x1xi32>
}

// CHECK-LABEL: @scatter_materialize_comprehensive
// CHECK: %[[EXPAND:.+]] = tensor.expand_shape %arg2 {{\[\[}}0], [1, 2]] : tensor<1x4xi32> into tensor<1x4x1xi32>
// CHECK: %[[SCATTER:.+]] = "mhlo.scatter"(%arg0, %arg1, %[[EXPAND]])
// CHECK:                   indices_are_sorted = true, scatter_dimension_numbers = #mhlo.scatter<
// CHECK-SAME:                 update_window_dims = [1, 2]
// CHECK-SAME:                 inserted_window_dims = [0]
// CHECK-SAME:                 scatter_dims_to_operand_dims = [0]
// CHECK-SAME:                 index_vector_dim = 1>, unique_indices = true

// -----

func.func @scatter_operand_map(%arg0: tensor<5x4x1xi32>, %arg1: tensor<1x2xi32>, %arg2: tensor<1xi32>) -> tensor<5x4x1xi32> {
  %0 = "mhlo.scatter"(%arg0, %arg1, %arg2) ({
  ^bb0(%arg3: tensor<i32>, %arg4: tensor<i32>):
    "mhlo.return"(%arg4) : (tensor<i32>) -> ()
  }) {
    indices_are_sorted = true,
    scatter_dimension_numbers = #mhlo.scatter<update_window_dims = [],
                                              inserted_window_dims = [0, 1, 2],
                                              scatter_dims_to_operand_dims = [0, 2],
                                              index_vector_dim = 1>,
    unique_indices = true} : (tensor<5x4x1xi32>, tensor<1x2xi32>, tensor<1xi32>) -> tensor<5x4x1xi32>
  return %0 : tensor<5x4x1xi32>
}

// CHECK-LABEL: @scatter_operand_map
// CHECK: %[[EXPAND:.+]] = tensor.expand_shape %arg2 {{\[\[}}0, 1, 2]] : tensor<1xi32> into tensor<1x1x1xi32>
// CHECK: %[[SCATTER:.+]] = "mhlo.scatter"(%arg0, %arg1, %[[EXPAND]])
// CHECK:                   indices_are_sorted = true, scatter_dimension_numbers = #mhlo.scatter<
// CHECK-SAME:                 update_window_dims = [1, 2],
// CHECK-SAME:                 inserted_window_dims = [0],
// CHECK-SAME:                 scatter_dims_to_operand_dims = [0, 2],
// CHECK-SAME:                 index_vector_dim = 1>, unique_indices = true
