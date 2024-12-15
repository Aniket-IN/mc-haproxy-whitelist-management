import axios from "axios";
import { useMemo, useState } from "react";

export type AxiosProps = {
    baseURL?: string;
    withCredentials?: boolean;
    withXSRFToken?: boolean;
    headers?: object;
};

const defaultHeaders = {
    "Content-Type": "application/json",
    Accept: "application/json",
};

const useAxios = ({
    withCredentials = true,
    withXSRFToken = true,
    headers = defaultHeaders,
}: AxiosProps = {}) => {
    const [processing, setProcessing] = useState(false);

    const axiosInstance = useMemo(() => {
        const instance = axios.create({
            headers: headers,
            withCredentials,
            withXSRFToken,
        });

        instance.interceptors.request.use(
            function (config) {
                setProcessing(true);
                return config;
            },
            function (error) {
                setProcessing(false);
                return Promise.reject(error);
            }
        );

        instance.interceptors.response.use(
            function (response) {
                setProcessing(false);
                return response;
            },
            function (error) {
                // aborted in useEffect cleanup
                if (error.code === "ERR_CANCELED") {
                    return Promise.resolve({ status: 499 });
                }

                setProcessing(false);
                return Promise.reject(error);
            }
        );

        return instance;
    }, [headers, withCredentials, withXSRFToken]);

    return {
        axios: axiosInstance,
        processing,
    };
};

export default useAxios;
