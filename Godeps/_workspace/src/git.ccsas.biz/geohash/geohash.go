package geohash

// #include <geohash/geohash.h>
// #include <string.h>
import "C"

import (
	"fmt"
	"unsafe"
)

const MaxGeohashLength = C.MAX_GEOHASH_LENGTH

func min(a int8, b int8) int8 {
	if a < b {
		return a
	}
	return b
}

func abs(a int8) int8 {
	if a < 0 {
		return -a
	}
	return a
}

func newGeohash(geohash string) *C.CCGeohashStruct {
	cgeohash := C.CString(geohash)
	cg := &C.CCGeohashStruct{}
	C.memset(unsafe.Pointer(&(cg.hash[0])), '0', MaxGeohashLength) // move this on C side
	C.strncpy(&(cg.hash[0]), cgeohash, C.size_t(len(geohash)))
	C.init_from_hash(cg)
	return cg
}

func GeohashFromCoordinates(latitude float64, longitude float64) string {
	cg := &C.CCGeohashStruct{latitude: C.double(latitude), longitude: C.double(longitude)}

	C.init_from_coordinates(cg)
	return C.GoString(&(cg.hash[0]))
}

func CoordinatesFromGeohash(geohash string) (float64, float64) {
	cg := newGeohash(geohash)
	return float64(cg.latitude), float64(cg.longitude)
}

func GeohashGridSurroundingGeohash(geohash string, radius int8) ([]string, error) {
	digits := int8(len(geohash))
	if digits > MaxGeohashLength {
		return nil, fmt.Errorf("Geohash length cannot be >= %d", MaxGeohashLength)
	}
	result := []string{}

	cg := newGeohash(geohash)

	power := MaxGeohashLength - digits
	digitsToMultiplier := power * power
	for i := -radius; i <= radius; i++ {
		for j := -radius; j <= radius; j++ {
			tmpgeohash := C.init_neighbour(cg, C.int(j*digitsToMultiplier), C.int(i*digitsToMultiplier))
			hash := C.GoString(&(tmpgeohash.hash[0]))
			result = append(result, hash[:digits])
		}
	}
	return result, nil
}
