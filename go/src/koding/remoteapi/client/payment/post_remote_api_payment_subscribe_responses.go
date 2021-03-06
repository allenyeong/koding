package payment

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the swagger generate command

import (
	"fmt"
	"io"

	"github.com/go-openapi/runtime"

	strfmt "github.com/go-openapi/strfmt"

	"koding/remoteapi/models"
)

// PostRemoteAPIPaymentSubscribeReader is a Reader for the PostRemoteAPIPaymentSubscribe structure.
type PostRemoteAPIPaymentSubscribeReader struct {
	formats strfmt.Registry
}

// ReadResponse reads a server response into the received o.
func (o *PostRemoteAPIPaymentSubscribeReader) ReadResponse(response runtime.ClientResponse, consumer runtime.Consumer) (interface{}, error) {
	switch response.Code() {

	case 200:
		result := NewPostRemoteAPIPaymentSubscribeOK()
		if err := result.readResponse(response, consumer, o.formats); err != nil {
			return nil, err
		}
		return result, nil

	case 401:
		result := NewPostRemoteAPIPaymentSubscribeUnauthorized()
		if err := result.readResponse(response, consumer, o.formats); err != nil {
			return nil, err
		}
		return nil, result

	default:
		return nil, runtime.NewAPIError("unknown error", response, response.Code())
	}
}

// NewPostRemoteAPIPaymentSubscribeOK creates a PostRemoteAPIPaymentSubscribeOK with default headers values
func NewPostRemoteAPIPaymentSubscribeOK() *PostRemoteAPIPaymentSubscribeOK {
	return &PostRemoteAPIPaymentSubscribeOK{}
}

/*PostRemoteAPIPaymentSubscribeOK handles this case with default header values.

Request processed succesfully
*/
type PostRemoteAPIPaymentSubscribeOK struct {
	Payload *models.DefaultResponse
}

func (o *PostRemoteAPIPaymentSubscribeOK) Error() string {
	return fmt.Sprintf("[POST /remote.api/Payment.subscribe][%d] postRemoteApiPaymentSubscribeOK  %+v", 200, o.Payload)
}

func (o *PostRemoteAPIPaymentSubscribeOK) readResponse(response runtime.ClientResponse, consumer runtime.Consumer, formats strfmt.Registry) error {

	o.Payload = new(models.DefaultResponse)

	// response payload
	if err := consumer.Consume(response.Body(), o.Payload); err != nil && err != io.EOF {
		return err
	}

	return nil
}

// NewPostRemoteAPIPaymentSubscribeUnauthorized creates a PostRemoteAPIPaymentSubscribeUnauthorized with default headers values
func NewPostRemoteAPIPaymentSubscribeUnauthorized() *PostRemoteAPIPaymentSubscribeUnauthorized {
	return &PostRemoteAPIPaymentSubscribeUnauthorized{}
}

/*PostRemoteAPIPaymentSubscribeUnauthorized handles this case with default header values.

Unauthorized request
*/
type PostRemoteAPIPaymentSubscribeUnauthorized struct {
	Payload *models.UnauthorizedRequest
}

func (o *PostRemoteAPIPaymentSubscribeUnauthorized) Error() string {
	return fmt.Sprintf("[POST /remote.api/Payment.subscribe][%d] postRemoteApiPaymentSubscribeUnauthorized  %+v", 401, o.Payload)
}

func (o *PostRemoteAPIPaymentSubscribeUnauthorized) readResponse(response runtime.ClientResponse, consumer runtime.Consumer, formats strfmt.Registry) error {

	o.Payload = new(models.UnauthorizedRequest)

	// response payload
	if err := consumer.Consume(response.Body(), o.Payload); err != nil && err != io.EOF {
		return err
	}

	return nil
}
