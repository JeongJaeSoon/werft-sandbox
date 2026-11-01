// Command consumer imports a private module and a public one, for the
// 94S-1181 session E2E.
package main

import (
	"fmt"

	"github.com/JeongJaeSoon/werft-sandbox/greet"
	"rsc.io/quote"
)

func main() {
	fmt.Println(greet.Hello())
	fmt.Println(quote.Hello())
}
