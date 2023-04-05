// Code generated by mockery v2.22.1. DO NOT EDIT.

package gasprice

import (
	big "math/big"

	context "github.com/0xPolygonHermez/zkevm-node/context"

	mock "github.com/stretchr/testify/mock"
)

// ethermanMock is an autogenerated mock type for the ethermanInterface type
type ethermanMock struct {
	mock.Mock
}

// GetL1GasPrice provides a mock function with given fields: ctx
func (_m *ethermanMock) GetL1GasPrice(ctx *context.RequestContext) *big.Int {
	ret := _m.Called(ctx)

	var r0 *big.Int
	if rf, ok := ret.Get(0).(func(*context.RequestContext) *big.Int); ok {
		r0 = rf(ctx)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*big.Int)
		}
	}

	return r0
}

type mockConstructorTestingTnewEthermanMock interface {
	mock.TestingT
	Cleanup(func())
}

// newEthermanMock creates a new instance of ethermanMock. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
func newEthermanMock(t mockConstructorTestingTnewEthermanMock) *ethermanMock {
	mock := &ethermanMock{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
