package services

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"regexp"
	"strconv"

	"code.google.com/p/go-uuid/uuid"
	"github.com/gin-gonic/gin"
	"github.com/lib/pq"
)

func GetHandlersV2(r *gin.RouterGroup, api_key string) {

	r.Use(version())
	private := r.Group("/")
	private.Use(privateRequest(api_key))
	public := r.Group("/")
	public.Use(publicRequest())

	/**
	 * Point urls
	 */
	private.POST("/point/", createPointHandler)
	private.PUT("/point/:point/", updatePointHandler)
	private.DELETE("/point/:point/", removePointHandler)

	/**
	 * Point meta urls
	 */
	private.POST("/pointmeta/", createPointMetaHandler)
	private.PUT("/pointmeta/:meta/", updatePointMetaHandler)
	private.DELETE("/pointmeta/:meta/", removePointMetaHandler)

	/**
	 * List urls
	 */
	private.POST("/list/", createListHandler)
	public.GET("/list/:list/", getCompleteListInfoHandler)
	private.PUT("/list/:list/", updateListHandler)
	public.GET("/list/:list/events/", consumeEventHandler)
	public.GET("/list/:list/zones/", fetchListGeohashZones)
	public.GET("/list/:list/annotation/", fetchMapAnnotations)
	public.GET("/list/:list/points/", fetchListPointHandler)
	private.POST("/list/:list/point/:point/", addPointToListHandler)
	private.DELETE("/list/:list/point/:point/", removePointFromListHandler)

	/**
	 * List meta urls
	 */
	private.POST("/listmeta/", createListMetaHandler)
	private.PUT("/listmeta/:meta/", updateListMetaHandler)
	private.DELETE("/listmeta/:meta/", removeListMetaHandler)

	/**
	 * event fetch methods
	 */
	public.GET("/events/", consumeEventHandler)

	public.GET("/event/point/", fetchPointsForEventsHandler)
	public.GET("/event/point_meta/", fetchPointMetasForEventsHandler)
	public.GET("/event/list_meta/", fetchListMetasForEventsHandler)
	public.GET("/event/list/", fetchListsForEventsHandler)
}

/**
 * Middlewares functions
 */

func version() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("version", "2")
		c.Next()
	}
}

func publicRequest() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId, err := getUserForRequest(c.Request)
		if err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusUnauthorized)
			c.AbortWithStatus(http.StatusUnauthorized)
			return
		}

		c.Set("userId", userId)
		c.Next()
	}
}

func privateRequest(api_key string) gin.HandlerFunc {
	return func(c *gin.Context) {
		t := c.Request.Header.Get("X-ParsemapAppKey")

		if t != api_key {
			outputJSONErrorCheckType(c.Writer, errors.New("Missing or wrong api header"), http.StatusUnauthorized)
			c.AbortWithStatus(http.StatusUnauthorized)
			return
		}

		c.Next()
	}
}

/**
 * Util methods
 */

func outputJSONErrorCheckType(w http.ResponseWriter, err error, code int) {
	if pqerr, ok := err.(*pq.Error); ok {
		errorContent := struct {
			Message string `json:"message"`
			Name    string `json:"name"`
		}{pqerr.Message, pqerr.Code.Name()}
		createJSONErrorResponse(w, errorContent, code)
	} else {
		outputJSONError(w, err.Error(), code)
	}
}

func outputJSONError(w http.ResponseWriter, message string, code int) {
	errR := struct{ Message string }{message}

	createJSONErrorResponse(w, errR, code)
}

func createJSONErrorResponse(w http.ResponseWriter, errorContent interface{}, code int) {
	encoder := json.NewEncoder(w)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := encoder.Encode(errorContent); err != nil {
		fmt.Println(err)
		return
	}
}

func getUserForRequest(r *http.Request) (uint64, error) {
	return 42, nil
}

func makeUint64ArrayWithIntArray(ints []int) []uint64 {
	results := make([]uint64, len(ints))
	for index, i := range ints {
		results[index] = uint64(i)
	}
	return results
}

func generateSQLIntArray(ints []uint64) string {
	if len(ints) == 0 {
		return "{}"
	}

	result := "{"
	for _, i := range ints {
		result = fmt.Sprintf("%s%s, ", result, strconv.Itoa(int(i)))
	}
	result = fmt.Sprintf("%s}", result[:len(result)-2])
	return result
}

func generateSQLStringArray(strings []string) string {
	reg, err := regexp.Compile("[\\w% -]+")
	if err != nil {
		return "{}"
	}

	if len(strings) == 0 {
		return "{}"
	}

	result := "{"
	for _, str := range strings {
		str = reg.FindString(str)
		result = fmt.Sprintf("%s\"%s\", ", result, str)
	}
	result = fmt.Sprintf("%s}", result[:len(result)-2])
	return result
}

func newUUID() string {
	var result bytes.Buffer
	length := 50

	for result.Len() < length {
		tmp := fmt.Sprintf("%s", uuid.NewUUID())
		extracted_len := len(tmp)
		if extracted_len+result.Len() > length {
			extracted_len = length - result.Len()
		}
		result.WriteString(tmp[:extracted_len])
	}
	return result.String()
}

/**
 * Misc
 */

func printRequestBody(r *http.Request) {
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(string(body))
}
