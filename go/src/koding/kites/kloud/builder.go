package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"reflect"

	"github.com/koding/kite"
)

// Builder is used to create and provisiong a single image or machine for a
// given Provider.
type Builder interface {
	Prepare(...interface{}) error
	Build() error
}

// Controller manages a machine
type Controller interface {
	Start() error
	Stop() error
	Restart() error
	Destroy() error
}

type buildArgs struct {
	Provider   string
	Credential map[string]interface{}
	Builder    map[string]interface{}
}

var providers = map[string]Builder{
	"digitalocean": &DigitalOcean{},
}

func build(r *kite.Request) (interface{}, error) {
	args := &buildArgs{}
	if err := r.Args.One().Unmarshal(args); err != nil {
		return nil, err
	}

	fmt.Printf("args %#v\n", args)

	provider, ok := providers[args.Provider]
	if !ok {
		return nil, errors.New("provider not supported")
	}

	if err := provider.Prepare(args.Credential, args.Builder); err != nil {
		return nil, err
	}

	if err := provider.Build(); err != nil {
		return nil, err
	}

	return true, nil
}

// templateData includes our klient converts the given raw interface to a
// []byte data that can used to pass into packer.Template().
func templateData(raw interface{}) ([]byte, error) {
	rawMapData, err := toMap(raw, "mapstructure")
	if err != nil {
		return nil, err
	}
	fmt.Printf("rawMapData %+v\n", rawMapData)

	packerTemplate := map[string]interface{}{}
	packerTemplate["builders"] = []interface{}{rawMapData}
	packerTemplate["provisioners"] = klientProvisioner
	fmt.Printf("packerTemplate %+v\n", packerTemplate)

	return json.Marshal(packerTemplate)
}

// toMap converts a struct defined by `in` to a map[string]interface{}. It only
// extract data that is defined by the given tag.
func toMap(in interface{}, tag string) (map[string]interface{}, error) {
	out := make(map[string]interface{})

	v := reflect.ValueOf(in)
	if v.Kind() == reflect.Ptr {
		v = v.Elem()
	}

	// we only accept structs
	if v.Kind() != reflect.Struct {
		return nil, fmt.Errorf("only struct is allowd got %T", v)
	}

	typ := v.Type()
	for i := 0; i < v.NumField(); i++ {
		// gets us a StructField
		fi := typ.Field(i)
		if tagv := fi.Tag.Get(tag); tagv != "" {
			// set key of map to value in struct field
			out[tagv] = v.Field(i).Interface()
		}
	}
	return out, nil

}
