#include <ATen/Context.h>
#include <ATen/Dispatch.h>
#include <ATen/native/cuda/Loops.cuh>
#include <ATen/native/DispatchStub.h>
#include <ATen/native/TensorIterator.h>
#include <ATen/native/BinaryOps.h>
#include <THC/THCNumerics.cuh>
#include <limits>


// NOTE: CUDA on Windows requires that the enclosing function
// of a __device__ lambda not have internal linkage.

namespace at { namespace native {

void add_kernel_cuda(TensorIterator& iter, Scalar alpha_scalar) {
  AT_DISPATCH_ALL_TYPES_AND2(kHalf, kBool, iter.dtype(), "add_cuda/sub_cuda", [&]() {
    auto alpha = alpha_scalar.to<scalar_t>();
    gpu_kernel_with_scalars(iter, [alpha]GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
      return a + alpha * b;
    });
  });
}

static void sub_kernel_cuda(TensorIterator& iter, Scalar alpha_scalar) {
  add_kernel_cuda(iter, -alpha_scalar);
}

void div_kernel_cuda(TensorIterator& iter) {
  if (!isIntegralType(iter.dtype(), /*includeBool*/ false) && iter.is_cpu_scalar(2)) {
    // optimization for floating-point types: if the second operand is a CPU
    // scalar, compute a * reciprocal(b). Note that this may lose one bit of
    // precision compared to computing the division.
    AT_DISPATCH_FLOATING_TYPES_AND_HALF(iter.dtype(), "div_cuda", [&]() {
      auto inv_b = scalar_t(1.0 / iter.scalar_value<scalar_t>(2));
      iter.remove_operand(2);
      gpu_kernel(iter, [inv_b]GPU_LAMBDA(scalar_t a) -> scalar_t {
        return a * inv_b;
      });
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "div_cuda", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a / b;
      });
    });
  }
}

void mul_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    // Workaround for the error: '*' in boolean context, suggest '&&' instead [-Werror=int-in-bool-context]
    gpu_kernel_with_scalars(iter, []GPU_LAMBDA(bool a, bool b) -> bool {
      return a && b;
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "mul_cuda", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a * b;
      });
    });
  }
}

void atan2_kernel_cuda(TensorIterator& iter) {
  AT_DISPATCH_FLOATING_TYPES_AND_HALF(iter.dtype(), "atan2_cuda", [&]() {
    gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
      return THCNumerics<scalar_t>::atan2(a, b);
    });
  });
}

void logical_xor_kernel_cuda(TensorIterator& iter) {
  gpu_kernel(iter, []GPU_LAMBDA(bool a, bool b) -> bool {
    return a != b;
  });
}

void lt_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    AT_DISPATCH_ALL_TYPES_AND2(kHalf, kBool, iter.input_dtype(), "lt_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> bool {
        return a < b;
      });
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "lt_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a < b;
      });
    });
  }
}

void le_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    AT_DISPATCH_ALL_TYPES_AND2(kHalf, kBool, iter.input_dtype(), "le_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> bool {
        return a <= b;
      });
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "le_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a <= b;
      });
    });
  }
}

void gt_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    AT_DISPATCH_ALL_TYPES_AND2(kHalf, kBool, iter.input_dtype(), "gt_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> bool {
        return a > b;
      });
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "gt_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a > b;
      });
    });
  }
}

void ge_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    AT_DISPATCH_ALL_TYPES_AND2(kHalf, kBool, iter.input_dtype(), "ge_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> bool {
        return a >= b;
      });
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "ge_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a >= b;
      });
    });
  }
}

void eq_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    AT_DISPATCH_ALL_TYPES_AND2(kHalf, kBool, iter.input_dtype(), "eq_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> bool {
        return a == b;
      });
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "eq_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a == b;
      });
    });
  }
}

void ne_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    AT_DISPATCH_ALL_TYPES_AND2(kHalf, kBool, iter.input_dtype(), "ne_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> bool {
        return a != b;
      });
    });
  } else {
    AT_DISPATCH_ALL_TYPES_AND(kHalf, iter.dtype(), "ne_cpu", [&]() {
      gpu_kernel_with_scalars(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return a != b;
      });
    });
  }
}

void max2_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    gpu_kernel(iter, []GPU_LAMBDA(bool a, bool b) -> bool {
      return a || b;
    });
  } else if (isIntegralType(iter.dtype(), /*includeBool*/ false)) {
    AT_DISPATCH_INTEGRAL_TYPES(iter.dtype(), "max2_cuda", [&]() {
      gpu_kernel(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return ::max(a, b);
      });
    });
  } else {
    AT_DISPATCH_FLOATING_TYPES_AND_HALF(iter.dtype(), "max2_cuda", [&]() {
      gpu_kernel(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        // We avoid using nan or nanf because we want to return the same type as scalar_t.
        if (::isnan(a)) {
          return a;
        } else if (::isnan(b)) {
          return b;
        } else {
          return ::max(a, b);
        }
      });
    });
  }
}

void min2_kernel_cuda(TensorIterator& iter) {
  if (iter.dtype() == ScalarType::Bool) {
    gpu_kernel(iter, []GPU_LAMBDA(bool a, bool b) -> bool {
      return a && b;
    });
  } else if (isIntegralType(iter.dtype(), /*includeBool*/ false)) {
    AT_DISPATCH_INTEGRAL_TYPES(iter.dtype(), "min2_cuda", [&]() {
      gpu_kernel(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        return ::min(a, b);
      });
    });
  } else {
    AT_DISPATCH_FLOATING_TYPES_AND_HALF(iter.dtype(), "min2_cuda", [&]() {
      gpu_kernel(iter, []GPU_LAMBDA(scalar_t a, scalar_t b) -> scalar_t {
        // We avoid using nan or nanf because we want to return the same type as scalar_t.
        if (::isnan(a)) {
          return a;
        } else if (::isnan(b)) {
          return b;
        } else {
          return ::min(a, b);
        }
      });
    });
  }
}

REGISTER_DISPATCH(add_stub, &add_kernel_cuda);
REGISTER_DISPATCH(sub_stub, &sub_kernel_cuda);
REGISTER_DISPATCH(div_stub, &div_kernel_cuda);
REGISTER_DISPATCH(mul_stub, &mul_kernel_cuda);
REGISTER_DISPATCH(atan2_stub, &atan2_kernel_cuda);
REGISTER_DISPATCH(logical_xor_stub, &logical_xor_kernel_cuda);
REGISTER_DISPATCH(lt_stub, &lt_kernel_cuda);
REGISTER_DISPATCH(le_stub, &le_kernel_cuda);
REGISTER_DISPATCH(gt_stub, &gt_kernel_cuda);
REGISTER_DISPATCH(ge_stub, &ge_kernel_cuda);
REGISTER_DISPATCH(eq_stub, &eq_kernel_cuda);
REGISTER_DISPATCH(ne_stub, &ne_kernel_cuda);
REGISTER_DISPATCH(max2_stub, &max2_kernel_cuda);
REGISTER_DISPATCH(min2_stub, &min2_kernel_cuda);

}} // namespace at::native
