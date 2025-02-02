// RUN: iree-opt -iree-codegen-gpu-tile-reduction --split-input-file -canonicalize -canonicalize -cse %s | FileCheck %s


func.func @warp_reduction_dispatch() {
  %cst = arith.constant 1.000000e+00 : f32
  %0 = hal.interface.binding.subspan set(0) binding(0) type(storage_buffer) : !flow.dispatch.tensor<readonly:tensor<512x10240xf32>>
  %1 = hal.interface.binding.subspan set(0) binding(1) type(storage_buffer) : !flow.dispatch.tensor<writeonly:tensor<512xf32>>
  %workgroup_id_x = hal.interface.workgroup.id[0] : index
  %2 = flow.dispatch.tensor.load %1, offsets = [%workgroup_id_x], sizes = [1], strides = [1] : !flow.dispatch.tensor<writeonly:tensor<512xf32>> -> tensor<1xf32>
  %3 = flow.dispatch.tensor.load %0, offsets = [%workgroup_id_x, 0], sizes = [1, 10240], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<512x10240xf32>> -> tensor<1x10240xf32>
  %4 = linalg.fill {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[1], [0, 2048]]>} ins(%cst : f32) outs(%2 : tensor<1xf32>) -> tensor<1xf32>
  %5 = linalg.generic {
    indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0)>],
    iterator_types = ["parallel", "reduction"]}
    ins(%3 : tensor<1x10240xf32>) outs(%4 : tensor<1xf32>)
    attrs =  {lowering_config = #iree_codegen.lowering_config<tile_sizes = [[1], [0, 2048]]>} {
  ^bb0(%in: f32, %out: f32):
    %6 = arith.addf %in, %out : f32
    linalg.yield %6 : f32
  } -> tensor<1xf32>
  flow.dispatch.tensor.store %5, %1, offsets = [%workgroup_id_x], sizes = [1], strides = [1] : tensor<1xf32> -> !flow.dispatch.tensor<writeonly:tensor<512xf32>>
  return
}

//   CHECK-DAG: #[[$MAP0:.+]] = affine_map<(d0, d1, d2) -> (d0, d1, d2)>
//   CHECK-DAG: #[[$MAP1:.+]] = affine_map<(d0, d1, d2) -> (d0, d2)>
//   CHECK-DAG: #[[$MAP2:.+]] = affine_map<(d0, d1) -> (d0, d1)>
//   CHECK-DAG: #[[$MAP3:.+]] = affine_map<(d0, d1) -> (d0)>
// CHECK-LABEL: warp_reduction_dispatch()
//   CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//   CHECK-DAG:   %[[C1:.+]] = arith.constant 1 : index
//   CHECK-DAG:   %[[C5:.+]] = arith.constant 5 : index
//   CHECK-DAG:   %[[IDEN:.+]] = arith.constant 0.000000e+00 : f32
//       CHECK:   %[[F0:.+]] = linalg.fill
//       CHECK:   %[[F1:.+]] = linalg.fill ins(%[[IDEN]] : f32) outs(%5 : tensor<1x2048xf32>) -> tensor<1x2048xf32>
//       CHECK:   %[[A1:.*]] = scf.for %[[IV:.+]] = %[[C0]] to %[[C5]] step %[[C1]] iter_args(%[[A0:.+]] = %[[F1]]) -> (tensor<1x2048xf32>) {
//       CHECK:     %[[S:.+]] = tensor.extract_slice %{{.*}}[0, %[[IV]], 0] [1, 1, 2048] [1, 1, 1] : tensor<1x5x2048xf32> to tensor<1x1x2048xf32>
//       CHECK:     %[[A2:.+]] = linalg.generic {indexing_maps = [#[[$MAP0]], #[[$MAP1]]], iterator_types = ["parallel", "reduction", "parallel"]} ins(%[[S]] : tensor<1x1x2048xf32>) outs(%[[A0]] : tensor<1x2048xf32>) {
//       CHECK:       arith.addf {{.*}} : f32
//       CHECK:     } -> tensor<1x2048xf32>
//       CHECK:     scf.yield %[[A2]] : tensor<1x2048xf32>
//       CHECK:   }
//       CHECK:   %[[A3:.+]] = linalg.generic {indexing_maps = [#[[$MAP2]], #[[$MAP3]]], iterator_types = ["parallel", "reduction"]} ins(%[[A1]] : tensor<1x2048xf32>) outs(%[[F0]] : tensor<1xf32>) {
//       CHECK:     arith.addf %in, %out : f32
//       CHECK:   } -> tensor<1xf32>
//       CHECK:   flow.dispatch.tensor.store %[[A3]]
