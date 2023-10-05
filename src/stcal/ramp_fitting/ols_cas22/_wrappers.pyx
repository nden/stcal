import numpy as np
cimport numpy as np

from libcpp cimport bool
from libcpp.stack cimport stack
from libcpp.deque cimport deque

from stcal.ramp_fitting.ols_cas22._core cimport RampIndex, ReadPatternMetadata, Thresh, threshold
from stcal.ramp_fitting.ols_cas22._core cimport metadata_from_read_pattern as c_metadata_from_read_pattern
from stcal.ramp_fitting.ols_cas22._core cimport init_ramps as c_init_ramps

from stcal.ramp_fitting.ols_cas22._fixed cimport FixedValues
from stcal.ramp_fitting.ols_cas22._fixed cimport fixed_values_from_metadata as c_fixed_values_from_metadata

from stcal.ramp_fitting.ols_cas22._pixel cimport Pixel
from stcal.ramp_fitting.ols_cas22._pixel cimport make_pixel as c_make_pixel


def metadata_from_read_pattern(list[list[int]] read_pattern, float read_time):
    return c_metadata_from_read_pattern(read_pattern, read_time)


def init_ramps(np.ndarray[int, ndim=2] dq):
    cdef deque[stack[RampIndex]] raw = c_init_ramps(dq)

    # Have to turn deque and stack into python compatible objects
    cdef RampIndex index
    cdef stack[RampIndex] ramp
    cdef list out = []
    cdef list stack_out
    for ramp in raw:
        stack_out = []
        while not ramp.empty():
            index = ramp.top()
            ramp.pop()
            # So top of stack is first item of list
            stack_out = [index] + stack_out

        out.append(stack_out)

    return out


def run_threshold(float intercept, float constant, float slope):
    cdef Thresh thresh = Thresh(intercept, constant)
    return threshold(thresh, slope)


def fixed_values_from_metadata(np.ndarray[float, ndim=1] t_bar,
                               np.ndarray[float, ndim=1] tau,
                               np.ndarray[int, ndim=1] n_reads,
                               float intercept,
                               float constant,
                               bool use_jump):

    cdef ReadPatternMetadata data = ReadPatternMetadata(t_bar, tau, n_reads)
    cdef Thresh threshold = Thresh(intercept, constant)

    cdef FixedValues fixed = c_fixed_values_from_metadata(data, threshold, use_jump)

    cdef float intercept_ = fixed.threshold.intercept
    cdef float constant_ = fixed.threshold.constant

    cdef np.ndarray[float, ndim=2] t_bar_diffs
    cdef np.ndarray[float, ndim=2] read_recip_coeffs
    cdef np.ndarray[float, ndim=2] var_slope_coeffs

    if use_jump:
        t_bar_diffs = np.array(fixed.t_bar_diffs, dtype=np.float32)
        read_recip_coeffs = np.array(fixed.read_recip_coeffs, dtype=np.float32)
        var_slope_coeffs = np.array(fixed.var_slope_coeffs, dtype=np.float32)
    else:
        try:
            fixed.t_bar_diffs
        except AttributeError:
            t_bar_diffs = np.array([[np.nan],[np.nan]], dtype=np.float32)
        else:
            raise AttributeError("t_bar_1 should not exist")

        try:
            fixed.read_recip_coeffs
        except AttributeError:
            read_recip_coeffs = np.array([[np.nan],[np.nan]], dtype=np.float32)
        else:
            raise AttributeError("recip_1 should not exist")

        try:
            fixed.var_slope_coeffs
        except AttributeError:
            var_slope_coeffs = np.array([[np.nan],[np.nan]], dtype=np.float32)
        else:
            raise AttributeError("slope_var_1 should not exist")

    return dict(data=fixed.data,
                intercept=intercept_,
                constant=constant_,
                t_bar_diffs=t_bar_diffs,
                read_recip_coeffs=read_recip_coeffs,
                var_slope_coeffs=var_slope_coeffs)


def make_pixel(np.ndarray[float, ndim=1] resultants,
               np.ndarray[float, ndim=1] t_bar,
               np.ndarray[float, ndim=1] tau,
               np.ndarray[int, ndim=1] n_reads,
               float read_noise,
               float intercept,
               float constant,
               bool use_jump):

    cdef ReadPatternMetadata data = ReadPatternMetadata(t_bar, tau, n_reads)
    cdef Thresh threshold = Thresh(intercept, constant)

    cdef FixedValues fixed = c_fixed_values_from_metadata(data, threshold, use_jump)

    cdef Pixel pixel = c_make_pixel(fixed, read_noise, resultants)

    cdef np.ndarray[float, ndim=1] resultants_ = np.array(pixel.resultants, dtype=np.float32)

    cdef np.ndarray[float, ndim=2] delta
    cdef np.ndarray[float, ndim=2] sigma

    if use_jump:
        delta = np.array(pixel.delta, dtype=np.float32)
        sigma = np.array(pixel.sigma, dtype=np.float32)
    else:
        try:
            pixel.delta
        except AttributeError:
            delta = np.array([[np.nan],[np.nan]], dtype=np.float32)
        else:
            raise AttributeError("delta_1 should not exist")

        try:
            pixel.sigma
        except AttributeError:
            sigma = np.array([[np.nan],[np.nan]], dtype=np.float32)
        else:
            raise AttributeError("sigma_1 should not exist")

    # only return computed values (assume fixed is correct)
    return dict(resultants=resultants_,
                read_noise=pixel.read_noise,
                delta=delta,
                sigma=sigma)
