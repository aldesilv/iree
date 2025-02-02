// RUN: iree-opt --split-input-file --pass-pipeline='hal.executable(hal.executable.variant(iree-codegen-linalg-to-spirv-pipeline))' --canonicalize --cse %s | FileCheck %s

#pipeline_layout = #hal.pipeline.layout<push_constants = 0, sets = [
  #hal.descriptor_set.layout<0, bindings = [
    #hal.descriptor_set.binding<0, storage_buffer>,
    #hal.descriptor_set.binding<1, storage_buffer>,
    #hal.descriptor_set.binding<2, storage_buffer>,
    #hal.descriptor_set.binding<3, storage_buffer>,
    #hal.descriptor_set.binding<4, storage_buffer>
  ]>
]>

hal.executable public @matmul_256x1024x128_div_add {
  hal.executable.variant @vulkan, target = <"vulkan-spirv", "vulkan-spirv-fb", {
    spirv.target_env = #spirv.target_env<
      #spirv.vce<v1.5,
      [Shader, Float16, StorageBuffer16BitAccess, StorageUniform16, CooperativeMatrixNV],
      [SPV_KHR_variable_pointers, SPV_NV_cooperative_matrix]>, NVIDIA:DiscreteGPU,
      #spirv.resource_limits<
        cooperative_matrix_properties_nv = [
          #spirv.coop_matrix_props<
            a_type = i8, b_type = i8, c_type = i32, k_size = 32,
            m_size = 8, n_size = 8, result_type = i32, scope = <Subgroup>>,
          #spirv.coop_matrix_props<
            a_type = f16, b_type = f16, c_type = f16, k_size = 16,
            m_size = 16, n_size = 16, result_type = f16, scope = <Subgroup>>,
          #spirv.coop_matrix_props<
            a_type = f16, b_type = f16, c_type = f32, k_size = 16,
            m_size = 16, n_size = 16, result_type = f32, scope = <Subgroup>>
        ],
        max_compute_shared_memory_size = 49152,
        max_compute_workgroup_invocations = 1024,
        max_compute_workgroup_size = [2147483647, 65535, 65535],
        subgroup_size = 32>
       >}> {
    hal.executable.export public @matmul_256x1024x128_div_add layout(#pipeline_layout) {
    ^bb0(%arg0: !hal.device, %arg1: index, %arg2 : index):
      %x, %y, %z = flow.dispatch.workgroup_count_from_dag_root %arg1, %arg2
      hal.return %x, %y, %z : index, index, index
    }
    builtin.module  {
      func.func @matmul_256x1024x128_div_add() {
        %c0 = arith.constant 0 : index
        %c1024 = arith.constant 1024 : index
        %c256 = arith.constant 256 : index
        %cst = arith.constant 0.000000e+00 : f16
        %0 = hal.interface.binding.subspan set(0) binding(0) type(storage_buffer) : !flow.dispatch.tensor<readonly:tensor<256x1024xf16>>
        %1 = hal.interface.binding.subspan set(0) binding(1) type(storage_buffer) : !flow.dispatch.tensor<readonly:tensor<256x1024xf16>>
        %2 = hal.interface.binding.subspan set(0) binding(2) type(storage_buffer) : !flow.dispatch.tensor<readonly:tensor<256x128xf16>>
        %3 = hal.interface.binding.subspan set(0) binding(3) type(storage_buffer) : !flow.dispatch.tensor<readonly:tensor<128x1024xf16>>
        %4 = hal.interface.binding.subspan set(0) binding(4) type(storage_buffer) : !flow.dispatch.tensor<writeonly:tensor<256x1024xf16>>
        %11 = flow.dispatch.tensor.load %0, offsets = [0, 0], sizes = [256, 1024], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<256x1024xf16>> -> tensor<256x1024xf16>
        %14 = flow.dispatch.tensor.load %1, offsets = [0, 0], sizes = [256, 1024], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<256x1024xf16>> -> tensor<256x1024xf16>
        %17 = tensor.empty() : tensor<256x1024xf16>
        %19 = flow.dispatch.tensor.load %2, offsets = [0, 0], sizes = [256, 128], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<256x128xf16>> -> tensor<256x128xf16>
        %21 = flow.dispatch.tensor.load %3, offsets = [0, 0], sizes = [128, 1204], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<128x1024xf16>> -> tensor<128x1024xf16>
        %24 = tensor.empty() : tensor<256x1024xf16>
        %25 = linalg.fill ins(%cst : f16) outs(%24 : tensor<256x1024xf16>) -> tensor<256x1024xf16>
        %26 = linalg.matmul ins(%19, %21 : tensor<256x128xf16>, tensor<128x1024xf16>) outs(%25 : tensor<256x1024xf16>) -> tensor<256x1024xf16>
        %27 = linalg.generic {
            indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0, d1)>],
            iterator_types = ["parallel", "parallel"]}
          ins(%26, %11, %14 : tensor<256x1024xf16>, tensor<256x1024xf16>, tensor<256x1024xf16>)
          outs(%17 : tensor<256x1024xf16>) {
        ^bb0(%arg2: f16, %arg3: f16, %arg4: f16, %arg5: f16):
          %28 = arith.divf %arg2, %arg3 : f16
          %29 = arith.addf %28, %arg4 : f16
          linalg.yield %29 : f16
        } -> tensor<256x1024xf16>
        flow.dispatch.tensor.store %27, %4, offsets = [0, 0], sizes = [256, 1024], strides = [1, 1] : tensor<256x1024xf16> -> !flow.dispatch.tensor<writeonly:tensor<256x1024xf16>>
        return
      }
    }
  }
}

//   CHECK-LABEL: spirv.module Logical GLSL450

// CHECK-COUNT-2:   spirv.GlobalVariable @{{.+}} : !spirv.ptr<!spirv.struct<(!spirv.array<1024 x f16>)>, Workgroup>

//         CHECK:   spirv.func @matmul_256x1024x128_div_add

//     CHECK-DAG:     %[[COL_MAJOR:.+]] = spirv.Constant [[COL_MAJOR]]
//     CHECK-DAG:     %[[C32:.+]] = spirv.Constant 32 : i32
//     CHECK-DAG:     %[[C1024:.+]] = spirv.Constant 1024 : i32
//     CHECK-DAG:     %[[F0:.+]] = spirv.Constant 0.000000e+00 : f16
//         CHECK:     %{{.+}} = spirv.CompositeConstruct %[[F0]] : (f16) -> !spirv.coopmatrix<16x16xf16, Subgroup>

//         CHECK:     %[[LOCAL_VAR:.+]] = spirv.Variable : !spirv.ptr<!spirv.coopmatrix<16x16xf16, Subgroup>, Function>
//         CHECK:     spirv.mlir.loop
//         CHECK:       spirv.ControlBarrier <Workgroup>, <Workgroup>, <AcquireRelease|WorkgroupMemory>
//         CHECK:       %{{.+}} = spirv.Load "StorageBuffer" %{{.+}} : vector<4xf32>
// CHECK-COUNT-8:       spirv.Store "Workgroup" %{{.+}}, %{{.+}} : f16
//         CHECK:       %{{.+}} = spirv.Load "StorageBuffer" %{{.+}} : vector<4xf32>
// CHECK-COUNT-8:       spirv.Store "Workgroup" %{{.+}}, %{{.+}} : f16
//         CHECK:       spirv.ControlBarrier <Workgroup>, <Workgroup>, <AcquireRelease|WorkgroupMemory>

//         CHECK:       %[[LD0:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:       %[[LD1:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>

//         CHECK:       %[[LD2:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:       %[[LD3:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>

//         CHECK:       %[[MA0:.+]] = spirv.NV.CooperativeMatrixMulAdd %[[LD0]], %[[LD2]], %{{.+}}
//         CHECK:       %[[MA1:.+]] = spirv.NV.CooperativeMatrixMulAdd %[[LD1]], %[[LD3]], %[[MA0]]

//         CHECK:       spirv.Store "Function" %[[LOCAL_VAR]], %[[MA1]]
//         CHECK:       spirv.mlir.merge

//         CHECK:     %[[LD_FN:.+]] = spirv.Load "Function" %[[LOCAL_VAR]] : !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     %[[LD4:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C1024]], %[[COL_MAJOR]] : !spirv.ptr<f16, StorageBuffer> as !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     %[[LD5:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C1024]], %[[COL_MAJOR]] : !spirv.ptr<f16, StorageBuffer> as !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     %[[DIV:.+]] = spirv.FDiv %[[LD_FN]], %[[LD4]] : !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     %[[ADD:.+]] = spirv.FAdd %[[DIV]], %[[LD5]] : !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     spirv.NV.CooperativeMatrixStore %{{.+}}, %[[ADD]], %[[C1024]], %[[COL_MAJOR]]

// -----

#pipeline_layout = #hal.pipeline.layout<push_constants = 0, sets = [
  #hal.descriptor_set.layout<0, bindings = [
    #hal.descriptor_set.binding<0, storage_buffer>,
    #hal.descriptor_set.binding<1, storage_buffer>,
    #hal.descriptor_set.binding<2, storage_buffer>,
    #hal.descriptor_set.binding<3, storage_buffer>,
    #hal.descriptor_set.binding<4, storage_buffer>
  ]>
]>
hal.executable public @batch_matmul_16x128x256x512_div {
  hal.executable.variant @vulkan, target = <"vulkan-spirv", "vulkan-spirv-fb", {
    spirv.target_env = #spirv.target_env<
      #spirv.vce<v1.5,
      [Shader, Float16, StorageBuffer16BitAccess, StorageUniform16, CooperativeMatrixNV],
      [SPV_KHR_variable_pointers, SPV_NV_cooperative_matrix]>, NVIDIA:DiscreteGPU,
      #spirv.resource_limits<
        cooperative_matrix_properties_nv = [
          #spirv.coop_matrix_props<
            a_type = i8, b_type = i8, c_type = i32, k_size = 32,
            m_size = 8, n_size = 8, result_type = i32, scope  = <Subgroup>>,
          #spirv.coop_matrix_props<
            a_type = f16, b_type = f16, c_type = f16, k_size = 16,
            m_size = 16, n_size = 16, result_type = f16, scope  = <Subgroup>>,
          #spirv.coop_matrix_props<
            a_type = f16, b_type = f16, c_type = f32, k_size = 16,
            m_size = 16, n_size = 16, result_type = f32, scope  = <Subgroup>>
        ],
        max_compute_shared_memory_size = 49152,
        max_compute_workgroup_invocations = 1024,
        max_compute_workgroup_size = [2147483647, 65535, 65535],
        subgroup_size = 32>
       >}> {
    hal.executable.export public @batch_matmul_16x128x256x512_div layout(#pipeline_layout) {
    ^bb0(%arg0: !hal.device, %arg1: index, %arg2: index, %arg3: index):
      %x, %y, %z = flow.dispatch.workgroup_count_from_dag_root %arg1, %arg2, %arg3
      hal.return %x, %y, %z : index, index, index
    }
    builtin.module {
      func.func @batch_matmul_16x128x256x512_div() {
        %c0 = arith.constant 0 : index
        %cst = arith.constant 0.000000e+00 : f16
        %0 = hal.interface.binding.subspan set(0) binding(0) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<readonly:tensor<16x128x512xf16>>
        %1 = hal.interface.binding.subspan set(0) binding(1) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<readonly:tensor<16x512x256xf16>>
        %2 = hal.interface.binding.subspan set(0) binding(2) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<readonly:tensor<16x128x256xf16>>
        %3 = hal.interface.binding.subspan set(0) binding(3) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<writeonly:tensor<16x128x256xf16>>
        %4 = flow.dispatch.tensor.load %0, offsets = [0, 0, 0], sizes = [16, 128, 512], strides = [1, 1, 1] : !flow.dispatch.tensor<readonly:tensor<16x128x512xf16>> -> tensor<16x128x512xf16>
        %5 = flow.dispatch.tensor.load %1, offsets = [0, 0, 0], sizes = [16, 512, 256], strides = [1, 1, 1] : !flow.dispatch.tensor<readonly:tensor<16x512x256xf16>> -> tensor<16x512x256xf16>
        %6 = flow.dispatch.tensor.load %2, offsets = [0, 0, 0], sizes = [16, 128, 256], strides = [1, 1, 1] : !flow.dispatch.tensor<readonly:tensor<16x128x256xf16>> -> tensor<16x128x256xf16>
        %7 = tensor.empty() : tensor<16x128x256xf16>
        %8 = linalg.fill ins(%cst : f16) outs(%7 : tensor<16x128x256xf16>) -> tensor<16x128x256xf16>
        %9 = linalg.batch_matmul ins(%4, %5 : tensor<16x128x512xf16>, tensor<16x512x256xf16>) outs(%8 : tensor<16x128x256xf16>) -> tensor<16x128x256xf16>
        %10 = linalg.generic {
            indexing_maps = [affine_map<(d0, d1, d2) -> (d0, d1, d2)>, affine_map<(d0, d1, d2) -> (d0, d1, d2)>, affine_map<(d0, d1, d2) -> (d0, d1, d2)>],
            iterator_types = ["parallel", "parallel", "parallel"]}
          ins(%9, %6 : tensor<16x128x256xf16>, tensor<16x128x256xf16>) outs(%7 : tensor<16x128x256xf16>) {
        ^bb0(%in: f16, %in_0: f16, %out: f16):
          %11 = arith.divf %in, %in_0 : f16
          linalg.yield %11 : f16
        } -> tensor<16x128x256xf16>
        flow.dispatch.tensor.store %10, %3, offsets = [0, 0, 0], sizes = [16, 128, 256], strides = [1, 1, 1] : tensor<16x128x256xf16> -> !flow.dispatch.tensor<writeonly:tensor<16x128x256xf16>>
        return
      }
    }
  }
}

//   CHECK-LABEL: spirv.module Logical GLSL450

// CHECK-COUNT-2:   spirv.GlobalVariable @{{.+}} : !spirv.ptr<!spirv.struct<(!spirv.array<1024 x f16>)>, Workgroup>

//         CHECK:   spirv.func @batch_matmul_16x128x256x512_div

//     CHECK-DAG:     %[[COL_MAJOR:.+]] = spirv.Constant [[COL_MAJOR]]
//     CHECK-DAG:     %[[C32:.+]] = spirv.Constant 32 : i32
//     CHECK-DAG:     %[[C256:.+]] = spirv.Constant 256 : i32
//     CHECK-DAG:     %[[F0:.+]] = spirv.Constant 0.000000e+00 : f16
//         CHECK:     %{{.+}} = spirv.CompositeConstruct %[[F0]] : (f16) -> !spirv.coopmatrix<16x16xf16, Subgroup>

//         CHECK:     %[[LOCAL_VAR:.+]] = spirv.Variable : !spirv.ptr<!spirv.coopmatrix<16x16xf16, Subgroup>, Function>
//         CHECK:     spirv.mlir.loop
//         CHECK:       spirv.ControlBarrier <Workgroup>, <Workgroup>, <AcquireRelease|WorkgroupMemory>
//         CHECK:       %{{.+}} = spirv.Load "StorageBuffer" %{{.+}} : vector<4xf32>
// CHECK-COUNT-8:       spirv.Store "Workgroup" %{{.+}}, %{{.+}} : f16
//         CHECK:       %{{.+}} = spirv.Load "StorageBuffer" %{{.+}} : vector<4xf32>
// CHECK-COUNT-8:       spirv.Store "Workgroup" %{{.+}}, %{{.+}} : f16
//         CHECK:       spirv.ControlBarrier <Workgroup>, <Workgroup>, <AcquireRelease|WorkgroupMemory>

//         CHECK:       %[[LD0:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:       %[[LD1:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>

//         CHECK:       %[[LD2:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:       %[[LD3:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C32]], %[[COL_MAJOR]] : !spirv.ptr<f16, Workgroup> as !spirv.coopmatrix<16x16xf16, Subgroup>

//         CHECK:       %[[MA0:.+]] = spirv.NV.CooperativeMatrixMulAdd %[[LD0]], %[[LD2]], %{{.+}}
//         CHECK:       %[[MA1:.+]] = spirv.NV.CooperativeMatrixMulAdd %[[LD1]], %[[LD3]], %[[MA0]]

//         CHECK:       spirv.Store "Function" %[[LOCAL_VAR]], %[[MA1]]
//         CHECK:       spirv.mlir.merge

//         CHECK:     %[[LD_FN:.+]] = spirv.Load "Function" %[[LOCAL_VAR]] : !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     %[[LD4:.+]] = spirv.NV.CooperativeMatrixLoad %{{.+}}, %[[C256]], %[[COL_MAJOR]] : !spirv.ptr<f16, StorageBuffer> as !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     %[[DIV:.+]] = spirv.FDiv %[[LD_FN]], %[[LD4]] : !spirv.coopmatrix<16x16xf16, Subgroup>
//         CHECK:     spirv.NV.CooperativeMatrixStore %{{.+}}, %[[DIV]], %[[C256]], %[[COL_MAJOR]]


// -----

#pipeline_layout = #hal.pipeline.layout<push_constants = 0, sets = [
  #hal.descriptor_set.layout<0, bindings = [
    #hal.descriptor_set.binding<0, storage_buffer>,
    #hal.descriptor_set.binding<1, storage_buffer>,
    #hal.descriptor_set.binding<2, storage_buffer>,
    #hal.descriptor_set.binding<3, storage_buffer>,
    #hal.descriptor_set.binding<4, storage_buffer>
  ]>
]>

hal.executable public @matmul_32x32x32_div {
  hal.executable.variant @vulkan, target = <"vulkan-spirv", "vulkan-spirv-fb", {
    spirv.target_env = #spirv.target_env<
      #spirv.vce<v1.5,
      [Shader, Float16, StorageBuffer16BitAccess, StorageUniform16, CooperativeMatrixNV],
      [SPV_KHR_variable_pointers, SPV_NV_cooperative_matrix]>, NVIDIA:DiscreteGPU,
      #spirv.resource_limits<
        cooperative_matrix_properties_nv = [
          #spirv.coop_matrix_props<
            a_type = i8, b_type = i8, c_type = i32, k_size = 32,
            m_size = 8, n_size = 8, result_type = i32, scope = <Subgroup>>,
          #spirv.coop_matrix_props<
            a_type = f16, b_type = f16, c_type = f16, k_size = 16,
            m_size = 16, n_size = 16, result_type = f16, scope = <Subgroup>>,
          #spirv.coop_matrix_props<
            a_type = f16, b_type = f16, c_type = f32, k_size = 16,
            m_size = 16, n_size = 16, result_type = f32, scope = <Subgroup>>
        ],
        max_compute_shared_memory_size = 49152,
        max_compute_workgroup_invocations = 1024,
        max_compute_workgroup_size = [2147483647, 65535, 65535],
        subgroup_size = 32>
       >}> {
    hal.executable.export public @matmul_32x32x32_div layout(#pipeline_layout) {
    ^bb0(%arg0: !hal.device, %arg1: index, %arg2 : index):
      %x, %y, %z = flow.dispatch.workgroup_count_from_dag_root %arg1, %arg2
      hal.return %x, %y, %z : index, index, index
    }
    builtin.module  {
      func.func @matmul_32x32x32_div() {
        %c0 = arith.constant 0 : index
        %cst = arith.constant 0.000000e+00 : f16
        %0 = hal.interface.binding.subspan set(0) binding(0) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<readonly:tensor<32x32xf16>>
        %1 = hal.interface.binding.subspan set(0) binding(1) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<readonly:tensor<32x32xf16>>
        %2 = hal.interface.binding.subspan set(0) binding(2) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<readonly:tensor<32x32xf16>>
        %3 = hal.interface.binding.subspan set(0) binding(3) type(storage_buffer) offset(%c0) alignment(64) : !flow.dispatch.tensor<writeonly:tensor<32x32xf16>>
        %4 = flow.dispatch.tensor.load %0, offsets = [0, 0], sizes = [32, 32], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<32x32xf16>> -> tensor<32x32xf16>
        %5 = flow.dispatch.tensor.load %1, offsets = [0, 0], sizes = [32, 32], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<32x32xf16>> -> tensor<32x32xf16>
        %6 = flow.dispatch.tensor.load %2, offsets = [0, 0], sizes = [32, 32], strides = [1, 1] : !flow.dispatch.tensor<readonly:tensor<32x32xf16>> -> tensor<32x32xf16>
        %7 = tensor.empty() : tensor<32x32xf16>
        %8 = linalg.fill ins(%cst : f16) outs(%7 : tensor<32x32xf16>) -> tensor<32x32xf16>
        %9 = linalg.matmul ins(%4, %5 : tensor<32x32xf16>, tensor<32x32xf16>) outs(%8 : tensor<32x32xf16>) -> tensor<32x32xf16>
        %10 = linalg.generic {
            indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0, d1)>, affine_map<(d0, d1) -> (d0, d1)>],
            iterator_types = ["parallel", "parallel"]}
        ins(%9, %6 : tensor<32x32xf16>, tensor<32x32xf16>) outs(%7 : tensor<32x32xf16>) {
        ^bb0(%in: f16, %in_0: f16, %out: f16):
          %11 = arith.divf %in, %in_0 : f16
          linalg.yield %11 : f16
        } -> tensor<32x32xf16>
        flow.dispatch.tensor.store %10, %3, offsets = [0, 0], sizes = [32, 32], strides = [1, 1] : tensor<32x32xf16> -> !flow.dispatch.tensor<writeonly:tensor<32x32xf16>>
        return
      }
    }
  }
}

//   CHECK-LABEL: spirv.module Logical GLSL450
// CHECK-COUNT-4: spirv.NV.CooperativeMatrixLoad
// CHECK-COUNT-2: spirv.NV.CooperativeMatrixMulAdd
//         CHECK: spirv.NV.CooperativeMatrixLoad
//         CHECK: spirv.FDiv
//         CHECK: spirv.NV.CooperativeMatrixStore
